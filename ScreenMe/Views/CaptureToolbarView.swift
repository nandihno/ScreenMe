import SwiftUI

struct CaptureToolbarView: View {
    let phase: CapturePhase
    let startSelectionCapture: () -> Void

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
                isActive: false
            )
            .disabled(true)
            .opacity(0.45)

            Spacer(minLength: 16)

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
        case .selecting:
            "Selecting..."
        case .capturing:
            "Capturing..."
        case .idle, .ready, .failed:
            "Capture"
        }
    }
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
