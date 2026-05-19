import CoreGraphics
import SwiftUI

struct CaptureToolbarView: View {
    let phase: CapturePhase
    let captureMode: CaptureMode
    @Binding var captureDelaySeconds: Int
    let fullScreenTargets: [FullScreenCaptureTarget]
    @Binding var selectedFullScreenTargetID: CGDirectDisplayID?
    let selectCaptureMode: (CaptureMode) -> Void
    let selectFullScreenTarget: (CGDirectDisplayID) -> Void
    let startCapture: () -> Void
    let cancelPendingCapture: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                Button {
                    selectCaptureMode(mode)
                } label: {
                    ModeButton(
                        title: mode.title,
                        systemImage: mode.systemImage,
                        isActive: captureMode == mode
                    )
                }
                .buttonStyle(.plain)
                .disabled(phase.isBusy)
            }

            Divider()
                .frame(height: 34)

            if captureMode == .full {
                FullScreenTargetPicker(
                    targets: fullScreenTargets,
                    selectedTargetID: fullScreenTargetBinding
                )
                .disabled(phase.isBusy || fullScreenTargets.isEmpty)

                Divider()
                    .frame(height: 34)
            }

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
                Button(action: startCapture) {
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
            if captureDelaySeconds > 0 {
                "\(captureMode.title) in \(captureDelaySeconds)s"
            } else {
                "Capture \(captureMode.title)"
            }
        }
    }

    private var clampedCaptureDelaySeconds: Binding<Int> {
        Binding {
            max(0, captureDelaySeconds)
        } set: { newValue in
            captureDelaySeconds = max(0, newValue)
        }
    }

    private var fullScreenTargetBinding: Binding<CGDirectDisplayID> {
        Binding {
            selectedFullScreenTargetID ?? fullScreenTargets.first?.id ?? 0
        } set: { newValue in
            selectedFullScreenTargetID = newValue
            selectFullScreenTarget(newValue)
        }
    }
}

private struct FullScreenTargetPicker: View {
    let targets: [FullScreenCaptureTarget]
    @Binding var selectedTargetID: CGDirectDisplayID

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "display")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            Picker("Full capture display", selection: $selectedTargetID) {
                ForEach(targets) { target in
                    Text(target.title)
                        .tag(target.id)
                }
            }
            .labelsHidden()
            .frame(width: 190)
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(.quaternary)
        }
        .accessibilityLabel("Full capture display")
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
