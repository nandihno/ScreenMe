import SwiftUI

struct CapturePreviewView: View {
    let capture: CapturedImage?
    let annotations: [CaptureAnnotation]
    let selectedAnnotationShape: CaptureAnnotationShape
    let selectedAnnotationColor: CaptureAnnotationColor
    let addAnnotation: (CGRect) -> Void

    @State private var draftAnnotationRect: CGRect?

    var body: some View {
        ZStack {
            Color.black.opacity(0.07)

            if let capture {
                CaptureAnnotationCanvas(
                    capture: capture,
                    annotations: annotations,
                    selectedAnnotationShape: selectedAnnotationShape,
                    selectedAnnotationColor: selectedAnnotationColor,
                    draftAnnotationRect: draftAnnotationRect,
                    updateDraftAnnotation: { draftAnnotationRect = $0 },
                    commitAnnotation: commitAnnotation
                )
                .padding(24)
            } else {
                EmptyPreviewState()
            }
        }
    }

    private func commitAnnotation(_ normalizedRect: CGRect?) {
        defer {
            draftAnnotationRect = nil
        }

        guard let normalizedRect else {
            return
        }

        addAnnotation(normalizedRect)
    }
}

private struct CaptureAnnotationCanvas: View {
    let capture: CapturedImage
    let annotations: [CaptureAnnotation]
    let selectedAnnotationShape: CaptureAnnotationShape
    let selectedAnnotationColor: CaptureAnnotationColor
    let draftAnnotationRect: CGRect?
    let updateDraftAnnotation: (CGRect?) -> Void
    let commitAnnotation: (CGRect?) -> Void

    var body: some View {
        GeometryReader { proxy in
            let imageFrame = aspectFitRect(
                imageSize: capture.pixelSize,
                containerSize: proxy.size
            )

            ZStack(alignment: .topLeading) {
                Image(nsImage: capture.image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .position(x: imageFrame.midX, y: imageFrame.midY)
                    .shadow(color: .black.opacity(0.28), radius: 16, y: 4)
                    .accessibilityLabel("Latest screenshot preview")

                ForEach(annotations) { annotation in
                    AnnotationShapeView(annotation: annotation, imageFrame: imageFrame)
                }

                if let draftAnnotationRect {
                    AnnotationShapeView(
                        annotation: CaptureAnnotation(
                            shape: selectedAnnotationShape,
                            normalizedRect: draftAnnotationRect,
                            strokeColor: selectedAnnotationColor
                        ),
                        imageFrame: imageFrame
                    )
                    .opacity(0.72)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(annotationGesture(imageFrame: imageFrame))
        }
    }

    private func annotationGesture(imageFrame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                updateDraftAnnotation(
                    normalizedRect(
                        from: value.startLocation,
                        to: value.location,
                        imageFrame: imageFrame
                    )
                )
            }
            .onEnded { value in
                commitAnnotation(
                    normalizedRect(
                        from: value.startLocation,
                        to: value.location,
                        imageFrame: imageFrame
                    )
                )
            }
    }

    private func normalizedRect(
        from startPoint: CGPoint,
        to endPoint: CGPoint,
        imageFrame: CGRect
    ) -> CGRect? {
        guard imageFrame.width > 0, imageFrame.height > 0 else {
            return nil
        }

        let start = clampedPoint(startPoint, to: imageFrame)
        let end = clampedPoint(endPoint, to: imageFrame)
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        guard rect.width >= 6, rect.height >= 6 else {
            return nil
        }

        return CGRect(
            x: (rect.minX - imageFrame.minX) / imageFrame.width,
            y: (rect.minY - imageFrame.minY) / imageFrame.height,
            width: rect.width / imageFrame.width,
            height: rect.height / imageFrame.height
        )
    }

    private func clampedPoint(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func aspectFitRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0,
              imageSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0
        else {
            return .zero
        }

        let scale = min(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let fittedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return CGRect(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}

private struct AnnotationShapeView: View {
    let annotation: CaptureAnnotation
    let imageFrame: CGRect

    var body: some View {
        Group {
            switch annotation.shape {
            case .rectangle:
                Rectangle()
                    .stroke(
                        annotation.strokeColor.color,
                        style: strokeStyle
                    )
            case .ellipse:
                Ellipse()
                    .stroke(
                        annotation.strokeColor.color,
                        style: strokeStyle
                    )
            }
        }
        .frame(width: denormalizedRect.width, height: denormalizedRect.height)
        .position(x: denormalizedRect.midX, y: denormalizedRect.midY)
        .shadow(color: .black.opacity(0.26), radius: 1, x: 0, y: 1)
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: annotation.lineWidth,
            lineCap: .round,
            lineJoin: .round
        )
    }

    private var denormalizedRect: CGRect {
        CGRect(
            x: imageFrame.minX + annotation.normalizedRect.minX * imageFrame.width,
            y: imageFrame.minY + annotation.normalizedRect.minY * imageFrame.height,
            width: annotation.normalizedRect.width * imageFrame.width,
            height: annotation.normalizedRect.height * imageFrame.height
        )
    }
}

private struct EmptyPreviewState: View {
    var body: some View {
        ContentUnavailableView(
            "No Capture Yet",
            systemImage: "rectangle.dashed",
            description: Text("Use Capture to take a screenshot.")
        )
    }
}
