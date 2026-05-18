import AppKit

enum CapturePhase: Equatable {
    case idle
    case requestingPermission
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
        case .requestingPermission, .selecting, .capturing:
            true
        case .idle, .ready, .failed:
            false
        }
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

    var dimensionsText: String {
        "\(Int(pixelSize.width)) x \(Int(pixelSize.height))"
    }

    var fileName: String {
        fileURL?.lastPathComponent ?? "Unsaved PNG"
    }
}
