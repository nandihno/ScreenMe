import AppKit
import CoreGraphics
import SwiftUI

enum CaptureAnnotationShape: String, CaseIterable, Identifiable {
    case rectangle
    case ellipse

    var id: Self { self }

    var title: String {
        switch self {
        case .rectangle:
            "Rectangle"
        case .ellipse:
            "Oval"
        }
    }

    var systemImage: String {
        switch self {
        case .rectangle:
            "rectangle"
        case .ellipse:
            "circle"
        }
    }
}

enum CaptureAnnotationColor: String, CaseIterable, Identifiable {
    case red
    case yellow
    case blue

    var id: Self { self }

    var title: String {
        switch self {
        case .red:
            "Red"
        case .yellow:
            "Yellow"
        case .blue:
            "Blue"
        }
    }

    var color: Color {
        switch self {
        case .red:
            .red
        case .yellow:
            .yellow
        case .blue:
            .blue
        }
    }

    nonisolated var nsColor: NSColor {
        switch self {
        case .red:
            .systemRed
        case .yellow:
            .systemYellow
        case .blue:
            .systemBlue
        }
    }
}

struct CaptureAnnotation: Identifiable, Equatable {
    let id: UUID
    let shape: CaptureAnnotationShape
    let normalizedRect: CGRect
    let strokeColor: CaptureAnnotationColor
    let lineWidth: CGFloat

    init(
        id: UUID = UUID(),
        shape: CaptureAnnotationShape,
        normalizedRect: CGRect,
        strokeColor: CaptureAnnotationColor,
        lineWidth: CGFloat = 4
    ) {
        self.id = id
        self.shape = shape
        self.normalizedRect = normalizedRect.standardized
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
    }
}
