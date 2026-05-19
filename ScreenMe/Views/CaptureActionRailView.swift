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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PhaseBadge(phase: phase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                Divider()

                VStack(spacing: 8) {
                    Button(action: copy) {
                        Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
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

                Divider()

                CaptureMetadataView(capture: capture)

                Divider()

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
                    Divider()
                    Button(action: openScreenRecordingSettings) {
                        Label("Screen Recording Settings", systemImage: "gearshape")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
            }
        }
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
            .symbolEffect(.pulse, isActive: phase.isBusy)
    }

    private var systemImage: String {
        switch phase {
        case .idle: "circle"
        case .requestingPermission: "lock"
        case .countingDown: "timer"
        case .selecting: "cursorarrow"
        case .capturing: "camera"
        case .ready: "checkmark.circle"
        case .failed: "exclamationmark.triangle"
        }
    }

    private var foreground: Color {
        switch phase {
        case .ready: .green
        case .failed: .orange
        case .requestingPermission, .countingDown, .selecting, .capturing: .red
        case .idle: .secondary
        }
    }
}

private struct CaptureMetadataView: View {
    let capture: CapturedImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details")
                .font(.subheadline.weight(.semibold))

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 6) {
                metadataRow("Dimensions", capture?.dimensionsText ?? "—")
                metadataRow("Mode", capture?.captureMode.title ?? "—")
                metadataRow("Format", "PNG")
                metadataRow("File", capture?.fileName ?? "—")
            }
            .font(.callout)
        }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(2)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Annotate")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if annotationCount > 0 {
                    Text("\(annotationCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.25), value: annotationCount)

            VStack(alignment: .leading, spacing: 6) {
                Text("Shape")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Shape", selection: shapeBinding) {
                    ForEach(CaptureAnnotationShape.allCases) { shape in
                        Label(shape.title, systemImage: shape.systemImage)
                            .tag(shape)
                    }
                }
                .pickerStyle(.palette)
                .labelsHidden()
                .disabled(!isEnabled)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Color", selection: colorBinding) {
                    ForEach(CaptureAnnotationColor.allCases) { color in
                        Label(color.title, systemImage: "circle.fill")
                            .tint(color.color)
                            .tag(color)
                    }
                }
                .pickerStyle(.palette)
                .labelsHidden()
                .disabled(!isEnabled)
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
                    Label("Clear All", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
                .disabled(!isEnabled || annotationCount == 0)
            }
        }
    }

    private var shapeBinding: Binding<CaptureAnnotationShape> {
        Binding(get: { selectedShape }, set: { selectShape($0) })
    }

    private var colorBinding: Binding<CaptureAnnotationColor> {
        Binding(get: { selectedColor }, set: { selectColor($0) })
    }
}
