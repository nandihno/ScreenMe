import AppKit
import CoreGraphics
import ImageIO

struct CapturedRegionFile: @unchecked Sendable {
    let image: CGImage
    let pngData: Data
    let fileURL: URL
}

enum ScreenCaptureServiceError: LocalizedError {
    case permissionDenied
    case noPicturesDirectory
    case captureReturnedNoImage
    case captureCommandFailed(String)
    case captureCancelled
    case captureTimedOut

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Screen Recording permission is required before ScreenMe can capture the selected region."
        case .noPicturesDirectory:
            "ScreenMe could not locate your Pictures folder."
        case .captureReturnedNoImage:
            "macOS did not return an image for the selected region."
        case .captureCommandFailed(let message):
            message.isEmpty
                ? "The system screenshot command failed."
                : "The system screenshot command failed: \(message)"
        case .captureCancelled:
            "Capture cancelled."
        case .captureTimedOut:
            "The system screenshot picker timed out."
        }
    }
}

final class ScreenCaptureService {
    private nonisolated static let maximumSavedCaptures = 10
    private nonisolated static let savedCapturePrefix = "ScreenMe-"
    private nonisolated static let savedCaptureExtension = "png"

    private let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    func captureInteractive(
        mode: CaptureMode,
        fullScreenTarget: FullScreenCaptureTarget?,
        capturedAt: Date
    ) async throws -> CapturedRegionFile {
        let fileURL = try nextPNGFileURL(capturedAt: capturedAt)

        return try await Task.detached(priority: .userInitiated) {
            let capturedFile = try Self.runScreenshotCommand(
                arguments: Self.screenshotArguments(
                    for: mode,
                    fullScreenTarget: fullScreenTarget,
                    fileURL: fileURL
                ),
                fileURL: fileURL
            )

            Self.pruneSavedCaptures(in: fileURL.deletingLastPathComponent())
            return capturedFile
        }.value
    }

    nonisolated private static func screenshotArguments(
        for mode: CaptureMode,
        fullScreenTarget: FullScreenCaptureTarget?,
        fileURL: URL
    ) -> [String] {
        switch mode {
        case .selection:
            return ["-i", "-s", "-x", fileURL.path]
        case .window:
            return ["-i", "-w", "-x", fileURL.path]
        case .full:
            if let fullScreenTarget {
                return ["-D", "\(fullScreenTarget.displayNumber)", "-x", fileURL.path]
            }

            return ["-x", fileURL.path]
        }
    }

    nonisolated private static func runScreenshotCommand(arguments: [String], fileURL: URL) throws -> CapturedRegionFile {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        try waitForProcess(process, timeout: 180)

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if message.isEmpty && !FileManager.default.fileExists(atPath: fileURL.path) {
                throw ScreenCaptureServiceError.captureCancelled
            }

            throw ScreenCaptureServiceError.captureCommandFailed(message)
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ScreenCaptureServiceError.captureCancelled
        }

        let pngData = try Data(contentsOf: fileURL)

        guard !pngData.isEmpty else {
            throw ScreenCaptureServiceError.captureCancelled
        }

        guard
            let source = CGImageSourceCreateWithData(pngData as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ScreenCaptureServiceError.captureReturnedNoImage
        }

        return CapturedRegionFile(image: image, pngData: pngData, fileURL: fileURL)
    }

    nonisolated private static func waitForProcess(_ process: Process, timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)

        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                throw ScreenCaptureServiceError.captureTimedOut
            }

            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    func copyToClipboard(_ capture: CapturedImage) {
        let item = NSPasteboardItem()
        item.setData(capture.pngData, forType: .png)

        if let tiffData = capture.image.tiffRepresentation {
            item.setData(tiffData, forType: .tiff)
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }

    private func nextPNGFileURL(capturedAt: Date) throws -> URL {
        guard let picturesDirectory = FileManager.default.urls(
            for: .picturesDirectory,
            in: .userDomainMask
        ).first else {
            throw ScreenCaptureServiceError.noPicturesDirectory
        }

        let folderURL = picturesDirectory.appendingPathComponent("ScreenMe", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )

        let timestamp = filenameFormatter.string(from: capturedAt)
        let baseName = "\(Self.savedCapturePrefix)\(timestamp)"
        let fileManager = FileManager.default
        var candidateURL = folderURL
            .appendingPathComponent(baseName)
            .appendingPathExtension(Self.savedCaptureExtension)

        var duplicateIndex = 2
        while fileManager.fileExists(atPath: candidateURL.path) {
            candidateURL = folderURL
                .appendingPathComponent("\(baseName)-\(duplicateIndex)")
                .appendingPathExtension(Self.savedCaptureExtension)
            duplicateIndex += 1
        }

        return candidateURL
    }

    nonisolated private static func pruneSavedCaptures(in folderURL: URL) {
        do {
            let captureFiles = try savedCaptureFiles(in: folderURL)

            guard captureFiles.count > maximumSavedCaptures else {
                return
            }

            let filesToDelete = captureFiles.dropLast(maximumSavedCaptures)
            for file in filesToDelete {
                try FileManager.default.removeItem(at: file.url)
            }
        } catch {
            NSLog("ScreenMe could not prune saved captures: \(error.localizedDescription)")
        }
    }

    nonisolated private static func savedCaptureFiles(in folderURL: URL) throws -> [(url: URL, date: Date)] {
        let resourceKeys: Set<URLResourceKey> = [
            .contentModificationDateKey,
            .creationDateKey,
            .isRegularFileKey
        ]

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )

        return fileURLs.compactMap { fileURL in
            guard isSavedCaptureFile(fileURL) else {
                return nil
            }

            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                return nil
            }

            guard resourceValues.isRegularFile == true else {
                return nil
            }

            let fileDate = resourceValues.contentModificationDate
                ?? resourceValues.creationDate
                ?? .distantPast

            return (url: fileURL, date: fileDate)
        }
        .sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.url.lastPathComponent < rhs.url.lastPathComponent
            }

            return lhs.date < rhs.date
        }
    }

    nonisolated private static func isSavedCaptureFile(_ fileURL: URL) -> Bool {
        let filename = fileURL.lastPathComponent
        return filename.hasPrefix(savedCapturePrefix)
            && fileURL.pathExtension.lowercased() == savedCaptureExtension
    }
}
