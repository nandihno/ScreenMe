import AppKit
import CoreGraphics

struct FullScreenCaptureTarget: Identifiable, Equatable, Sendable {
    let id: CGDirectDisplayID
    let displayNumber: Int
    let name: String
    let frame: CGRect
    let isMain: Bool

    var title: String {
        isMain ? "\(name) (Main)" : name
    }

    var detailText: String {
        "\(Int(frame.width)) x \(Int(frame.height)) pts"
    }
}

enum CaptureMode: String, Equatable {
    case selection
    case window
    case full
    case saved

    static let allCases: [CaptureMode] = [
        .selection,
        .window,
        .full
    ]

    var title: String {
        switch self {
        case .selection:
            "Selection"
        case .window:
            "Window"
        case .full:
            "Full"
        case .saved:
            "Saved"
        }
    }

    var systemImage: String {
        switch self {
        case .selection:
            "rectangle.dashed"
        case .window:
            "macwindow"
        case .full:
            "rectangle.inset.filled"
        case .saved:
            "photo"
        }
    }

    var startStatus: String {
        switch self {
        case .selection:
            "Use the macOS picker to drag a region. Press Esc to cancel."
        case .window:
            "Use the macOS picker to choose a window. Press Esc to cancel."
        case .full:
            "ScreenMe will hide and capture the full screen."
        case .saved:
            "Saved capture selected."
        }
    }

    var captureStatus: String {
        switch self {
        case .selection, .window:
            "Waiting for the system screenshot picker..."
        case .full:
            "Capturing the full screen..."
        case .saved:
            "Loading saved capture..."
        }
    }

    var savedDescription: String {
        switch self {
        case .selection:
            "selection capture"
        case .window:
            "window capture"
        case .full:
            "full-screen capture"
        case .saved:
            "saved capture"
        }
    }

    var usesInteractivePicker: Bool {
        switch self {
        case .selection, .window:
            true
        case .full, .saved:
            false
        }
    }
}

enum CapturePhase: Equatable {
    case idle
    case requestingPermission
    case countingDown(Int)
    case selecting
    case capturing
    case ready
    case failed(String)

    var label: String {
        switch self {
        case .idle:
            "Ready"
        case .requestingPermission:
            "Requesting Permission"
        case .countingDown(let remainingSeconds):
            "Starting in \(remainingSeconds)s"
        case .selecting:
            "Selecting"
        case .capturing:
            "Capturing"
        case .ready:
            "Capture Ready"
        case .failed:
            "Needs Attention"
        }
    }

    var isBusy: Bool {
        switch self {
        case .requestingPermission, .countingDown, .selecting, .capturing:
            true
        case .idle, .ready, .failed:
            false
        }
    }

    var isCountingDown: Bool {
        if case .countingDown = self {
            return true
        }

        return false
    }
}

struct CapturedImage: Identifiable {
    let id = UUID()
    let image: NSImage
    let pngData: Data
    let fileURL: URL?
    let pixelSize: CGSize
    let capturedAt: Date
    let sourceRect: CGRect
    let captureMode: CaptureMode

    var dimensionsText: String {
        "\(Int(pixelSize.width)) x \(Int(pixelSize.height))"
    }

    var fileName: String {
        fileURL?.lastPathComponent ?? "Unsaved PNG"
    }
}
