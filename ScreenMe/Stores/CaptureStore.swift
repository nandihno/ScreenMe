import AppKit
import Combine

@MainActor
final class CaptureStore: ObservableObject {
    @Published private(set) var phase: CapturePhase = .idle
    @Published private(set) var latestCapture: CapturedImage?
    @Published var captureDelaySeconds = 0
    @Published var statusMessage = "Select part of the screen to create a PNG."

    private let captureService: ScreenCaptureService
    private var hiddenWindows: [NSWindow] = []
    private var captureTask: Task<Void, Never>?

    init(captureService: ScreenCaptureService? = nil) {
        self.captureService = captureService ?? ScreenCaptureService()
    }

    var canCopy: Bool {
        latestCapture != nil
    }

    var canReveal: Bool {
        latestCapture?.fileURL != nil
    }

    func startSelectionCapture() {
        guard !phase.isBusy else {
            return
        }

        captureTask = Task {
            await prepareAndStartSelection()
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

        captureService.copyToClipboard(latestCapture)
        statusMessage = "Copied \(latestCapture.dimensionsText) PNG to the clipboard."
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

    private func prepareAndStartSelection() async {
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

        phase = .selecting
        statusMessage = "Use the macOS picker to drag a region. Press Esc to cancel."
        hideAppWindows()

        await handleSystemPickerCapture()
    }

    private func handleSystemPickerCapture() async {
        defer {
            restoreAppWindows()
            captureTask = nil
        }

        phase = .capturing
        statusMessage = "Waiting for the system screenshot picker..."

        do {
            let capturedAt = Date()
            let capturedRegion = try await captureService.captureInteractiveRegion(capturedAt: capturedAt)
            statusMessage = "Saved \(capturedRegion.fileURL.lastPathComponent) to Pictures/ScreenMe."

            latestCapture = CapturedImage(
                image: NSImage(
                    cgImage: capturedRegion.image,
                    size: NSSize(width: capturedRegion.image.width, height: capturedRegion.image.height)
                ),
                pngData: capturedRegion.pngData,
                fileURL: capturedRegion.fileURL,
                pixelSize: CGSize(width: capturedRegion.image.width, height: capturedRegion.image.height),
                capturedAt: capturedAt,
                sourceRect: .zero
            )
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
}
