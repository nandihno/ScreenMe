import SwiftUI

struct ContentView: View {
    @StateObject private var captureStore = CaptureStore()
    @State private var inspectorPresented = true

    var body: some View {
        NavigationSplitView {
            CaptureLibraryView(
                recentCaptures: captureStore.recentCaptures,
                selectedCaptureID: captureStore.selectedRecentCaptureID,
                phase: captureStore.phase,
                refresh: { captureStore.refreshRecentCaptures() },
                selectCapture: captureStore.selectRecentCapture
            )
            .navigationSplitViewColumnWidth(min: 190, ideal: 250, max: 320)
            .onAppear { captureStore.refreshRecentCaptures() }
        } detail: {
            CapturePreviewView(
                capture: captureStore.latestCapture,
                annotations: captureStore.annotations,
                selectedAnnotationShape: captureStore.selectedAnnotationShape,
                selectedAnnotationColor: captureStore.selectedAnnotationColor,
                addAnnotation: captureStore.addAnnotation
            )
            .inspector(isPresented: $inspectorPresented) {
                CaptureActionRailView(captureStore: captureStore)
                    .inspectorColumnWidth(min: 220, ideal: 240, max: 280)
            }
        }
        .toolbar {
            CaptureToolbarContent(
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
        }
        .frame(minWidth: 900, minHeight: 560)
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

#Preview {
    ContentView()
}
