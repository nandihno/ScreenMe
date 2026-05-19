# ScreenMe

A macOS screenshot app (SwiftUI, AppKit-bridged) that captures a selection, a window, or a full display, saves the result as PNG into `~/Pictures/ScreenMe/`, and exposes copy/reveal actions. The active capture can be annotated in-memory with rectangle/oval overlays before copying. Single-window app, no document model, no persistence beyond the PNG folder.

## How it works

The app shells out to the system `/usr/sbin/screencapture` binary rather than using `ScreenCaptureKit`. This sidesteps direct Screen Recording permission management — the system tool prompts the user the first time and macOS remembers the grant for the app bundle.

Capture flow (`CaptureStore.startCapture`):
1. Optional countdown via `runCountdown(seconds:)` — drives the `.countingDown(n)` phase, cancellable via `cancelPendingCapture()`.
2. `hideAppWindows()` calls `orderOut` on the app's visible windows so they don't appear in the screenshot.
3. `ScreenCaptureService.captureInteractive` runs `screencapture` on a detached task with the right flags for the mode (`-i -s` selection, `-i -w` window, `-D <n>` for a specific display).
4. The resulting PNG is read back from disk, decoded via `CGImageSource`, and wrapped in a `CapturedImage`.
5. `restoreAppWindows()` re-orders windows in and reactivates the app.
6. `pruneSavedCaptures` trims `~/Pictures/ScreenMe/` to the most recent 10 `ScreenMe-*.png` files (sorted by mtime).

Cancellation: if `screencapture -i` exits non-zero with no stderr and no file written (user pressed Esc), the service throws `.captureCancelled`, which the store translates back to `.idle` or `.ready` depending on whether a prior capture exists.

## Architecture

Plain MV / `ObservableObject` + SwiftUI. No SwiftData, no Combine pipelines beyond `@Published`. One `@MainActor` store owns all state; views are stateless and take values + closures.

```
ScreenMeApp (WindowGroup, hiddenTitleBar)
└── ContentView
    ├── header
    ├── CaptureToolbarView          mode picker · display picker · timer · capture/cancel
    ├── Annotate workspace
    │   ├── CapturePreviewView      active NSImage or empty state · annotation overlay gestures
    │   └── CaptureActionRailView   phase badge · copy · reveal · metadata · annotation tools · status
    └── Recent workspace
        ├── CaptureLibraryView      last 10 saved PNGs · thumbnail selection
        └── CaptureActionRailView   same active-capture actions
```

### Layers

- **App entry** — [ScreenMeApp.swift](ScreenMe/ScreenMeApp.swift): single `WindowGroup`, `.hiddenTitleBar`, `.contentMinSize`.
- **State** — [CaptureStore.swift](ScreenMe/Stores/CaptureStore.swift): `@MainActor final class CaptureStore: ObservableObject`. Owns `phase`, `latestCapture`, `captureMode`, `captureDelaySeconds`, `fullScreenTargets`, `selectedFullScreenTargetID`, recent-capture library state, annotation state, and `statusMessage`. All user intents are methods on the store (`selectCaptureMode`, `startCapture`, `cancelPendingCapture`, `copyLatestCapture`, `revealLatestPNG`, recent refresh/select, annotation select/add/undo/clear, `openScreenRecordingSettings`).
- **Service** — [ScreenCaptureService.swift](ScreenMe/Services/ScreenCaptureService.swift): pure side-effect layer. Builds `screencapture` arguments, runs the `Process`, prunes old files, writes to the clipboard. `nonisolated` static helpers run off the main actor inside `Task.detached`.
- **Models** — [CapturedImage.swift](ScreenMe/Models/CapturedImage.swift), [CaptureAnnotation.swift](ScreenMe/Models/CaptureAnnotation.swift), [RecentCaptureItem.swift](ScreenMe/Models/RecentCaptureItem.swift):
  - `CaptureMode` (`.selection` / `.window` / `.full`) — also carries UI copy and the `usesInteractivePicker` flag.
  - `CapturePhase` (`.idle`, `.requestingPermission`, `.countingDown(Int)`, `.selecting`, `.capturing`, `.ready`, `.failed(String)`) — the single source of truth for what the UI is doing; `isBusy` gates re-entry.
  - `FullScreenCaptureTarget` — a `CGDirectDisplayID` plus display number/name/frame for the `-D` flag.
  - `CapturedImage` — `NSImage` + raw PNG `Data` + optional `fileURL` + pixel size + mode + timestamp.
  - `CaptureAnnotation` — rectangle/oval overlays stored as normalized image-space rects with stroke color and line width.
  - `RecentCaptureItem` — decoded saved PNG metadata used by the recent-captures browser and promotion into `CapturedImage`.
- **Views** — [Views/](ScreenMe/Views): toolbar, preview, action rail. Stateless: each receives the phase + capture + callbacks from `ContentView`.

### Annotation flow

Annotations are viewable overlays on the active capture and are not written back to the saved PNG file. `CaptureStore` owns the committed annotation list and resets it whenever a new capture succeeds. `CapturePreviewView` owns only transient drag state while the user is drawing; committed rectangles are sent back to the store as normalized image coordinates so they survive preview resizing. `copyLatestCapture()` renders annotations into a temporary PNG for the pasteboard when overlays are present; `revealLatestPNG()` still reveals the original raw screenshot file.

### Recent capture flow

`ScreenCaptureService.recentCaptures()` scans `~/Pictures/ScreenMe/` for `ScreenMe-*.png`, decodes up to the newest 10, and returns `RecentCaptureItem` values. `CaptureStore.selectRecentCapture(_:)` promotes the selected item into `latestCapture` with mode `.saved`, making the existing annotation editor, copy, reveal, metadata, and status paths work without duplication. In-memory annotations are keyed by capture file URL while the app is running, so switching between recent captures preserves unsaved overlays for that session.

### Data flow

```
View action ──▶ closure on CaptureStore ──▶ mutates @Published state
                                          │
                                          └─▶ async ScreenCaptureService call
                                                          │
                                                          ▼
                                          PNG file on disk + CapturedImage
                                                          │
                                                          ▼
                                          latestCapture / phase / statusMessage update
                                                          │
                                                          ▼
                                                    SwiftUI redraw
```

## Conventions

- **Concurrency**: the store is `@MainActor`; the service is plain `final class` with `nonisolated` statics for the work that runs in `Task.detached`. `CapturedRegionFile` is `@unchecked Sendable` to cross the actor boundary with a `CGImage`.
- **Files**: `~/Pictures/ScreenMe/ScreenMe-yyyyMMdd-HHmmss.png`, suffixed `-2`, `-3`, … on collision. Folder is auto-created. Hard cap of 10 files, oldest pruned.
- **Permissions**: sandboxed with `com.apple.security.assets.pictures.read-write` ([ScreenMe.entitlements](ScreenMe/ScreenMe.entitlements)). Capture still runs through `/usr/sbin/screencapture`, but `CaptureStore` preflights Screen Recording access for the running ScreenMe process so the UI can fail cleanly instead of entering a repeated macOS permission prompt loop. The "Screen Recording Settings" button is shown on `.failed` as a fallback.
- **Screen Recording / TCC debugging**: if macOS repeatedly says "ScreenMe.app would like to record this computer's screen and audio" even though System Settings shows ScreenMe enabled, suspect a stale TCC entry or code-signing identity mismatch. Screen Recording approval is tied to the app's code identity. Builds made with `CODE_SIGNING_ALLOWED=NO` are ad-hoc signed and can appear as a different identity from a normally signed Xcode build (`org.nando.ScreenMe`, team `D58U53H2X6`). Reset the stale grant with `tccutil reset ScreenCapture org.nando.ScreenMe`, run a normally signed build, grant Screen Recording once, then quit and reopen ScreenMe. Do not validate this flow from an unsigned/ad-hoc build.
- **Phase as state machine**: every UI gate (`disabled`, button labels, status text) reads from `CapturePhase`. Don't add parallel booleans — extend the enum.
- **Views are dumb**: views never own state beyond local `@Binding` plumbing or transient gesture state; all committed logic lives in `CaptureStore`. Keep new features in the store.

## Build

Xcode project at [ScreenMe.xcodeproj](ScreenMe.xcodeproj). No SPM dependencies. Target: macOS, SwiftUI lifecycle. Build with `xcodebuild -project ScreenMe.xcodeproj -scheme ScreenMe` or open in Xcode.
