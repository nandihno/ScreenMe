import SwiftUI

struct ContentView: View {
    @StateObject private var captureStore = CaptureStore()

    var body: some View {
        VStack(spacing: 16) {
            header

            CaptureToolbarView(
                phase: captureStore.phase,
                startSelectionCapture: captureStore.startSelectionCapture
            )

            HStack(spacing: 16) {
                CapturePreviewView(capture: captureStore.latestCapture)

                CaptureActionRailView(
                    phase: captureStore.phase,
                    capture: captureStore.latestCapture,
                    statusMessage: captureStore.statusMessage,
                    copy: captureStore.copyLatestCapture,
                    reveal: captureStore.revealLatestPNG,
                    openScreenRecordingSettings: captureStore.openScreenRecordingSettings
                )
            }
        }
        .padding(22)
        .frame(minWidth: 880, minHeight: 560)
        .background {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.red.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ScreenMe")
                    .font(.largeTitle.weight(.semibold))

                Text("Capture a selected screen region, save it as PNG, and copy it when needed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Phase 1")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.red.opacity(0.12), in: Capsule())
        }
    }
}

#Preview {
    ContentView()
}
