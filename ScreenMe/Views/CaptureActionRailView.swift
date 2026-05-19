import SwiftUI

struct CaptureActionRailView: View {
    let phase: CapturePhase
    let capture: CapturedImage?
    let selectedAnnotationShape: CaptureAnnotationShape
    let selectedAnnotationColor: CaptureAnnotationColor
    let annotations: [CaptureAnnotation]
    let statusMessage: String
    let copy: () -> Void
    let reveal: () -> Void
    let selectAnnotationShape: (CaptureAnnotationShape) -> Void
    let selectAnnotationColor: (CaptureAnnotationColor) -> Void
    let undoAnnotation: () -> Void
    let clearAnnotations: () -> Void
    let openScreenRecordingSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Active Capture")
                    .font(.headline)

                PhaseBadge(phase: phase)
            }

            Divider()

            VStack(spacing: 10) {
                Button(action: copy) {
                    Label("Copy", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("c", modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
                .disabled(capture == nil)

                Button(action: reveal) {
                    Label("Reveal in Finder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(capture?.fileURL == nil)
            }

            CaptureMetadataView(capture: capture)

            AnnotationControlsView(
                selectedShape: selectedAnnotationShape,
                selectedColor: selectedAnnotationColor,
                annotationCount: annotations.count,
                isEnabled: capture != nil && !phase.isBusy,
                selectShape: selectAnnotationShape,
                selectColor: selectAnnotationColor,
                undoAnnotation: undoAnnotation,
                clearAnnotations: clearAnnotations
            )

            if case .failed = phase {
                Button(action: openScreenRecordingSettings) {
                    Label("Screen Recording Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Text(statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 240)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary)
        }
    }
}

private struct AnnotationControlsView: View {
    let selectedShape: CaptureAnnotationShape
    let selectedColor: CaptureAnnotationColor
    let annotationCount: Int
    let isEnabled: Bool
    let selectShape: (CaptureAnnotationShape) -> Void
    let selectColor: (CaptureAnnotationColor) -> Void
    let undoAnnotation: () -> Void
    let clearAnnotations: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Annotate")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(annotationCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(CaptureAnnotationShape.allCases) { shape in
                    Button {
                        selectShape(shape)
                    } label: {
                        Image(systemName: shape.systemImage)
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(selectedShape == shape ? .red : nil)
                    .help(shape.title)
                    .disabled(!isEnabled)
                }

                Divider()
                    .frame(height: 24)

                ForEach(CaptureAnnotationColor.allCases) { color in
                    Button {
                        selectColor(color)
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        selectedColor == color ? .primary : .quaternary,
                                        lineWidth: selectedColor == color ? 2 : 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .help(color.title)
                    .disabled(!isEnabled)
                }
            }

            HStack(spacing: 8) {
                Button(action: undoAnnotation) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!isEnabled || annotationCount == 0)

                Button(action: clearAnnotations) {
                    Label("Clear", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!isEnabled || annotationCount == 0)
            }
        }
        .font(.callout)
    }
}

private struct PhaseBadge: View {
    let phase: CapturePhase

    var body: some View {
        Label(phase.label, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(foreground.opacity(0.12), in: Capsule())
    }

    private var systemImage: String {
        switch phase {
        case .idle:
            "circle"
        case .requestingPermission:
            "lock"
        case .countingDown:
            "timer"
        case .selecting:
            "cursorarrow"
        case .capturing:
            "camera"
        case .ready:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle"
        }
    }

    private var foreground: Color {
        switch phase {
        case .ready:
            .green
        case .failed:
            .orange
        case .requestingPermission, .countingDown, .selecting, .capturing:
            .red
        case .idle:
            .secondary
        }
    }
}

private struct CaptureMetadataView: View {
    let capture: CapturedImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details")
                .font(.subheadline.weight(.semibold))

            MetadataRow(title: "Dimensions", value: capture?.dimensionsText ?? "--")
            MetadataRow(title: "Mode", value: capture?.captureMode.title ?? "--")
            MetadataRow(title: "Format", value: "PNG")
            MetadataRow(title: "File", value: capture?.fileName ?? "--")
        }
        .font(.callout)
    }
}

private struct MetadataRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }
}
