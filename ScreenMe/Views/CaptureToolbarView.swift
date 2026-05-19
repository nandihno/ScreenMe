import CoreGraphics
import SwiftUI

struct CaptureToolbarContent: ToolbarContent {
    let phase: CapturePhase
    let captureMode: CaptureMode
    @Binding var captureDelaySeconds: Int
    let fullScreenTargets: [FullScreenCaptureTarget]
    @Binding var selectedFullScreenTargetID: CGDirectDisplayID?
    let selectCaptureMode: (CaptureMode) -> Void
    let selectFullScreenTarget: (CGDirectDisplayID) -> Void
    let startCapture: () -> Void
    let cancelPendingCapture: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Picker("Capture Mode", selection: modeBinding) {
                ForEach(CaptureMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.systemImage)
                        .help(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .disabled(phase.isBusy)

            if captureMode == .full && !fullScreenTargets.isEmpty {
                Picker("Display", selection: displayBinding) {
                    ForEach(fullScreenTargets) { target in
                        Text(target.title).tag(target.id)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
                .disabled(phase.isBusy)
            }
        }

        ToolbarItem(placement: .automatic) {
            timerMenu
        }

        ToolbarItem(placement: .primaryAction) {
            captureButton
        }
    }

    private var modeBinding: Binding<CaptureMode> {
        Binding(
            get: { captureMode },
            set: { selectCaptureMode($0) }
        )
    }

    private var displayBinding: Binding<CGDirectDisplayID> {
        Binding(
            get: { selectedFullScreenTargetID ?? fullScreenTargets.first?.id ?? 0 },
            set: { id in
                selectedFullScreenTargetID = id
                selectFullScreenTarget(id)
            }
        )
    }

    private var timerMenu: some View {
        Menu {
            Button {
                captureDelaySeconds = 0
            } label: {
                if captureDelaySeconds == 0 {
                    Label("No Delay", systemImage: "checkmark")
                } else {
                    Text("No Delay")
                }
            }
            Divider()
            ForEach([3, 5, 10], id: \.self) { seconds in
                Button {
                    captureDelaySeconds = seconds
                } label: {
                    if captureDelaySeconds == seconds {
                        Label("\(seconds) Seconds", systemImage: "checkmark")
                    } else {
                        Text("\(seconds) Seconds")
                    }
                }
            }
        } label: {
            Label(
                captureDelaySeconds > 0 ? "\(captureDelaySeconds)s" : "Timer",
                systemImage: "timer"
            )
            .foregroundStyle(captureDelaySeconds > 0 ? .primary : .secondary)
        }
        .disabled(phase.isBusy)
        .help("Capture delay timer")
    }

    @ViewBuilder
    private var captureButton: some View {
        if phase.isCountingDown {
            Button(action: cancelPendingCapture) {
                Label("Cancel", systemImage: "xmark.circle.fill")
            }
            .tint(.orange)
        } else {
            Button(action: startCapture) {
                Label(captureButtonTitle, systemImage: "camera.viewfinder")
                    .symbolEffect(.pulse, isActive: phase.isBusy)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(phase.isBusy)
            .keyboardShortcut("5", modifiers: [.control, .command])
        }
    }

    private var captureButtonTitle: String {
        switch phase {
        case .requestingPermission: "Checking…"
        case .selecting: "Selecting…"
        case .capturing: "Capturing…"
        default:
            captureDelaySeconds > 0
                ? "\(captureMode.title) in \(captureDelaySeconds)s"
                : "Capture \(captureMode.title)"
        }
    }
}
