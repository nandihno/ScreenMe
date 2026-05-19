import SwiftUI

struct ContentView: View {
    @StateObject private var captureStore = CaptureStore()
    @State private var selectedWorkspaceTab: WorkspaceTab = .annotate

    var body: some View {
        VStack(spacing: 16) {
            header

            CaptureToolbarView(
                phase: captureStore.phase,
                captureMode: captureStore.captureMode,
                captureDelaySeconds: $captureStore.captureDelaySeconds,
                fullScreenTargets: captureStore.fullScreenTargets,
                selectedFullScreenTargetID: $captureStore.selectedFullScreenTargetID,
                selectCaptureMode: captureStore.selectCaptureMode,
                selectFullScreenTarget: captureStore.selectFullScreenTarget,
                startCapture: captureStore.startCapture,
                cancelPendingCapture: captureStore.cancelPendingCapture
            )

            Picker("Workspace", selection: $selectedWorkspaceTab) {
                Label("Annotate", systemImage: "pencil.and.outline")
                    .tag(WorkspaceTab.annotate)
                Label("Recent", systemImage: "photo.on.rectangle")
                    .tag(WorkspaceTab.recent)
            }
            .pickerStyle(.segmented)
            .frame(width: 260)

            switch selectedWorkspaceTab {
            case .annotate:
                AnnotationWorkspaceView(captureStore: captureStore)
            case .recent:
                RecentWorkspaceView(
                    captureStore: captureStore,
                    openForAnnotation: { item in
                        captureStore.selectRecentCapture(item)
                        selectedWorkspaceTab = .annotate
                    }
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

            Text("Phase 2")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.red.opacity(0.12), in: Capsule())
        }
    }
}

private struct AnnotationWorkspaceView: View {
    @ObservedObject var captureStore: CaptureStore

    var body: some View {
        HStack(spacing: 16) {
            CapturePreviewView(
                capture: captureStore.latestCapture,
                annotations: captureStore.annotations,
                selectedAnnotationShape: captureStore.selectedAnnotationShape,
                selectedAnnotationColor: captureStore.selectedAnnotationColor,
                addAnnotation: captureStore.addAnnotation
            )

            CaptureActionRailView(captureStore: captureStore)
        }
    }
}

private struct RecentWorkspaceView: View {
    @ObservedObject var captureStore: CaptureStore
    let openForAnnotation: (RecentCaptureItem) -> Void

    var body: some View {
        HStack(spacing: 16) {
            CaptureLibraryView(
                recentCaptures: captureStore.recentCaptures,
                selectedCaptureID: captureStore.selectedRecentCaptureID,
                phase: captureStore.phase,
                refresh: { captureStore.refreshRecentCaptures() },
                selectCapture: captureStore.selectRecentCapture,
                openForAnnotation: openForAnnotation
            )

            CaptureActionRailView(captureStore: captureStore)
        }
        .onAppear {
            captureStore.refreshRecentCaptures()
        }
    }
}

private extension CaptureActionRailView {
    init(captureStore: CaptureStore) {
        self.init(
            phase: captureStore.phase,
            capture: captureStore.latestCapture,
            selectedAnnotationShape: captureStore.selectedAnnotationShape,
            selectedAnnotationColor: captureStore.selectedAnnotationColor,
            annotations: captureStore.annotations,
            statusMessage: captureStore.statusMessage,
            copy: captureStore.copyLatestCapture,
            reveal: captureStore.revealLatestPNG,
            selectAnnotationShape: captureStore.selectAnnotationShape,
            selectAnnotationColor: captureStore.selectAnnotationColor,
            undoAnnotation: captureStore.undoLatestAnnotation,
            clearAnnotations: captureStore.clearAnnotations,
            openScreenRecordingSettings: captureStore.openScreenRecordingSettings
        )
    }
}

private enum WorkspaceTab {
    case annotate
    case recent
}

#Preview {
    ContentView()
}
