import AppKit
import Combine

@MainActor
final class CaptureStore: ObservableObject {
    @Published private(set) var phase: CapturePhase = .idle
    @Published private(set) var latestCapture: CapturedImage?
    @Published var captureMode: CaptureMode = .selection
    @Published var captureDelaySeconds = 0
    @Published private(set) var fullScreenTargets: [FullScreenCaptureTarget] = []
    @Published var selectedFullScreenTargetID: CGDirectDisplayID?
    @Published var selectedAnnotationShape: CaptureAnnotationShape = .rectangle
    @Published var selectedAnnotationColor: CaptureAnnotationColor = .red
    @Published private(set) var annotations: [CaptureAnnotation] = []
    @Published private(set) var recentCaptures: [RecentCaptureItem] = []
    @Published private(set) var selectedRecentCaptureID: URL?
    @Published var statusMessage = "Select part of the screen to create a PNG."

    private let captureService: ScreenCaptureService
    private var hiddenWindows: [NSWindow] = []
    private var captureTask: Task<Void, Never>?
    private var annotationsByCaptureID: [URL: [CaptureAnnotation]] = [:]

    init(captureService: ScreenCaptureService? = nil) {
        self.captureService = captureService ?? ScreenCaptureService()
        refreshFullScreenTargets()
        refreshRecentCaptures(updateStatus: false)
    }

    var canCopy: Bool {
        latestCapture != nil
    }

    var canReveal: Bool {
        latestCapture?.fileURL != nil
    }

    var canUndoAnnotation: Bool {
        !annotations.isEmpty
    }

    func selectCaptureMode(_ mode: CaptureMode) {
        guard !phase.isBusy else {
            return
        }

        captureMode = mode
        if mode == .full {
            refreshFullScreenTargets(preferAppWindowScreen: true)
        }
        statusMessage = "\(mode.title) capture selected."
    }

    func selectFullScreenTarget(id: CGDirectDisplayID) {
        guard !phase.isBusy else {
            return
        }

        selectedFullScreenTargetID = id
        if let target = selectedFullScreenTarget {
            statusMessage = "Full capture will use \(target.title)."
        }
    }

    func startCapture() {
        guard !phase.isBusy else {
            return
        }

        let mode = captureMode
        captureTask = Task {
            await prepareAndStartCapture(mode: mode)
        }
    }

    func cancelPendingCapture() {
        guard phase.isCountingDown else {
            return
        }

        captureTask?.cancel()
        captureTask = nil
        phase = latestCapture == nil ? .idle : .ready
        statusMessage = latestCapture == nil
            ? "Timed capture cancelled. Start a new capture when ready."
            : "Timed capture cancelled. The previous capture is still available."
    }

    func copyLatestCapture() {
        guard let latestCapture else {
            return
        }

        let copiedAnnotatedImage = captureService.copyToClipboard(
            latestCapture,
            annotations: annotations
        )
        let annotationDescription = copiedAnnotatedImage ? " annotated" : ""
        statusMessage = "Copied\(annotationDescription) \(latestCapture.dimensionsText) PNG to the clipboard."
    }

    func revealLatestPNG() {
        guard let fileURL = latestCapture?.fileURL else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func refreshRecentCaptures(updateStatus: Bool = true) {
        do {
            recentCaptures = try captureService.recentCaptures()
            if updateStatus {
                statusMessage = recentCaptures.isEmpty
                    ? "No saved captures found in Pictures/ScreenMe."
                    : "Loaded \(recentCaptures.count) recent capture\(recentCaptures.count == 1 ? "" : "s")."
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func selectRecentCapture(_ item: RecentCaptureItem) {
        guard !phase.isBusy else {
            return
        }

        saveAnnotationsForCurrentCapture()
        latestCapture = item.capturedImage()
        selectedRecentCaptureID = item.id
        annotations = annotationsByCaptureID[item.id] ?? []
        phase = .ready
        statusMessage = "Selected \(item.fileName) for annotation."
    }

    func selectAnnotationShape(_ shape: CaptureAnnotationShape) {
        selectedAnnotationShape = shape
        statusMessage = "\(shape.title) annotation selected."
    }

    func selectAnnotationColor(_ color: CaptureAnnotationColor) {
        selectedAnnotationColor = color
        statusMessage = "\(color.title) annotation color selected."
    }

    func addAnnotation(normalizedRect: CGRect) {
        guard latestCapture != nil else {
            return
        }

        let standardizedRect = normalizedRect.standardized
        guard standardizedRect.width >= 0.01, standardizedRect.height >= 0.01 else {
            return
        }

        annotations.append(
            CaptureAnnotation(
                shape: selectedAnnotationShape,
                normalizedRect: standardizedRect,
                strokeColor: selectedAnnotationColor
            )
        )
        saveAnnotationsForCurrentCapture()
        phase = .ready
        statusMessage = "Added \(selectedAnnotationShape.title.lowercased()) annotation."
    }

    func undoLatestAnnotation() {
        guard !annotations.isEmpty else {
            return
        }

        annotations.removeLast()
        saveAnnotationsForCurrentCapture()
        statusMessage = annotations.isEmpty
            ? "Removed the last annotation. The capture is clean."
            : "Removed the last annotation."
    }

    func clearAnnotations() {
        guard !annotations.isEmpty else {
            return
        }

        annotations.removeAll()
        saveAnnotationsForCurrentCapture()
        statusMessage = "Cleared annotations from the current capture."
    }

    private func prepareAndStartCapture(mode: CaptureMode) async {
        let delaySeconds = max(0, captureDelaySeconds)

        if delaySeconds > 0 {
            do {
                try await runCountdown(seconds: delaySeconds)
            } catch {
                return
            }
        }

        guard !Task.isCancelled else {
            return
        }

        if mode == .full {
            refreshFullScreenTargets(preferAppWindowScreen: selectedFullScreenTargetID == nil)
        }

        let fullScreenTarget = mode == .full ? selectedFullScreenTarget : nil
        phase = mode.usesInteractivePicker ? .selecting : .capturing
        if let fullScreenTarget {
            statusMessage = "ScreenMe will hide and capture \(fullScreenTarget.title)."
        } else {
            statusMessage = mode.startStatus
        }
        hideAppWindows()
        try? await Task.sleep(for: .milliseconds(200))

        await handleSystemPickerCapture(mode: mode, fullScreenTarget: fullScreenTarget)
    }

    private func handleSystemPickerCapture(
        mode: CaptureMode,
        fullScreenTarget: FullScreenCaptureTarget?
    ) async {
        defer {
            restoreAppWindows()
            captureTask = nil
        }

        phase = .capturing
        statusMessage = mode.captureStatus

        do {
            let capturedAt = Date()
            let capturedRegion = try await captureService.captureInteractive(
                mode: mode,
                fullScreenTarget: fullScreenTarget,
                capturedAt: capturedAt
            )
            let savedDescription = fullScreenTarget?.title ?? mode.savedDescription
            statusMessage = "Saved \(savedDescription) \(capturedRegion.fileURL.lastPathComponent) to Pictures/ScreenMe."
            saveAnnotationsForCurrentCapture()
            annotations.removeAll()

            latestCapture = CapturedImage(
                image: NSImage(
                    cgImage: capturedRegion.image,
                    size: NSSize(width: capturedRegion.image.width, height: capturedRegion.image.height)
                ),
                pngData: capturedRegion.pngData,
                fileURL: capturedRegion.fileURL,
                pixelSize: CGSize(width: capturedRegion.image.width, height: capturedRegion.image.height),
                capturedAt: capturedAt,
                sourceRect: fullScreenTarget?.frame ?? .zero,
                captureMode: mode
            )
            selectedRecentCaptureID = capturedRegion.fileURL
            refreshRecentCaptures(updateStatus: false)
            phase = .ready
        } catch ScreenCaptureServiceError.captureCancelled {
            phase = latestCapture == nil ? .idle : .ready
            statusMessage = latestCapture == nil
                ? "Capture cancelled. Start a new capture when ready."
                : "Capture cancelled. The previous capture is still available."
        } catch {
            phase = .failed(error.localizedDescription)
            statusMessage = error.localizedDescription
        }
    }

    private func hideAppWindows() {
        hiddenWindows = NSApp.windows.filter { window in
            window.isVisible && !window.isMiniaturized
        }

        hiddenWindows.forEach { $0.orderOut(nil) }
    }

    private func restoreAppWindows() {
        hiddenWindows.forEach { $0.makeKeyAndOrderFront(nil) }
        hiddenWindows.removeAll()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func runCountdown(seconds: Int) async throws {
        for remainingSeconds in stride(from: seconds, through: 1, by: -1) {
            try Task.checkCancellation()
            phase = .countingDown(remainingSeconds)
            statusMessage = "Capture starts in \(remainingSeconds) second\(remainingSeconds == 1 ? "" : "s")."
            try await Task.sleep(for: .seconds(1))
        }
    }

    private func saveAnnotationsForCurrentCapture() {
        guard let fileURL = latestCapture?.fileURL else {
            return
        }

        annotationsByCaptureID[fileURL] = annotations
    }

    private var selectedFullScreenTarget: FullScreenCaptureTarget? {
        guard let selectedFullScreenTargetID else {
            return fullScreenTargets.first
        }

        return fullScreenTargets.first { $0.id == selectedFullScreenTargetID }
            ?? fullScreenTargets.first
    }

    private func refreshFullScreenTargets(preferAppWindowScreen: Bool = false) {
        let previousSelection = selectedFullScreenTargetID
        let screens = NSScreen.screens
        fullScreenTargets = screens.enumerated().compactMap { index, screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }

            return FullScreenCaptureTarget(
                id: displayID,
                displayNumber: index + 1,
                name: screen.localizedName,
                frame: screen.frame,
                isMain: screen == NSScreen.main
            )
        }

        if preferAppWindowScreen, let appDisplayID = appWindowDisplayID() {
            selectedFullScreenTargetID = appDisplayID
        } else if let previousSelection,
                  fullScreenTargets.contains(where: { $0.id == previousSelection }) {
            selectedFullScreenTargetID = previousSelection
        } else {
            selectedFullScreenTargetID = appWindowDisplayID() ?? fullScreenTargets.first?.id
        }
    }

    private func appWindowDisplayID() -> CGDirectDisplayID? {
        let candidateWindow = NSApp.keyWindow
            ?? NSApp.mainWindow
            ?? NSApp.windows.first { $0.isVisible && !$0.isMiniaturized }

        guard let screen = candidateWindow?.screen else {
            return NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        }

        return screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
