import AppKit
import CoreGraphics

struct RecentCaptureItem: Identifiable {
    var id: URL { fileURL }

    let fileURL: URL
    let image: NSImage
    let pngData: Data
    let pixelSize: CGSize
    let capturedAt: Date

    var fileName: String {
        fileURL.lastPathComponent
    }

    var dimensionsText: String {
        "\(Int(pixelSize.width)) x \(Int(pixelSize.height))"
    }

    func capturedImage() -> CapturedImage {
        CapturedImage(
            image: image,
            pngData: pngData,
            fileURL: fileURL,
            pixelSize: pixelSize,
            capturedAt: capturedAt,
            sourceRect: .zero,
            captureMode: .saved
        )
    }
}
