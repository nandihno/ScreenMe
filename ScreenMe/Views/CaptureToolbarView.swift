import SwiftUI

struct CaptureToolbarView: View {
    let phase: CapturePhase
    @Binding var captureDelaySeconds: Int
    let startSelectionCapture: () -> Void
    let cancelPendingCapture: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ModeButton(
                title: "Selection",
                systemImage: "rectangle.dashed",
                isActive: true
            )

            ModeButton(
                title: "Window",
                systemImage: "macwindow",
                isActive: false
            )
            .disabled(true)
            .opacity(0.45)

            ModeButton(
                title: "Full",
                systemImage: "rectangle.inset.filled",
                isActive: false
            )
            .disabled(true)
            .opacity(0.45)

            Divider()
                .frame(height: 34)

            ModeButton(
                title: "Timer",
                systemImage: "timer",
                isActive: captureDelaySeconds > 0 || phase.isCountingDown
            )

            TimerDelayControl(seconds: clampedCaptureDelaySeconds)
                .disabled(phase.isBusy)

            Spacer(minLength: 16)

            if phase.isCountingDown {
                Button(action: cancelPendingCapture) {
                    Label("Cancel", systemImage: "xmark.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(minWidth: 112)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else {
                Button(action: startSelectionCapture) {
                    Label(buttonTitle, systemImage: "camera.viewfinder")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(minWidth: 132)
                }
                .keyboardShortcut("5", modifiers: [.control, .command])
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
                .disabled(phase.isBusy)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary)
        }
    }

    private var buttonTitle: String {
        switch phase {
        case .requestingPermission:
            "Checking..."
        case .countingDown(let remainingSeconds):
            "Starting \(remainingSeconds)s"
        case .selecting:
            "Selecting..."
        case .capturing:
            "Capturing..."
        case .idle, .ready, .failed:
            captureDelaySeconds > 0 ? "Capture in \(captureDelaySeconds)s" : "Capture"
        }
    }

    private var clampedCaptureDelaySeconds: Binding<Int> {
        Binding {
            max(0, captureDelaySeconds)
        } set: { newValue in
            captureDelaySeconds = max(0, newValue)
        }
    }
}

private struct TimerDelayControl: View {
    @Binding var seconds: Int

    var body: some View {
        HStack(spacing: 7) {
            TextField("0", value: $seconds, formatter: Self.formatter)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 58)

            Text("sec")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stepper("Capture delay", value: $seconds, step: 1)
                .labelsHidden()
                .frame(width: 28)
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(.quaternary)
        }
        .accessibilityLabel("Capture delay in seconds")
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 0
        formatter.usesGroupingSeparator = false
        return formatter
    }()
}

private struct ModeButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .frame(height: 20)

            Text(title)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(width: 70, height: 54)
        .foregroundStyle(isActive ? .primary : .secondary)
        .background {
            if isActive {
                RoundedRectangle(cornerRadius: 7)
                    .fill(.background.opacity(0.72))
            }
        }
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(.red.opacity(0.55))
            }
        }
    }
}
