import SwiftUI

struct CaptureLibraryView: View {
    let recentCaptures: [RecentCaptureItem]
    let selectedCaptureID: URL?
    let phase: CapturePhase
    let refresh: () -> Void
    let selectCapture: (RecentCaptureItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 105, maximum: 155), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 0) {
            libraryHeader
            Divider()
            if recentCaptures.isEmpty {
                ContentUnavailableView(
                    "No Captures",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Screenshots will appear here after saving.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(recentCaptures) { item in
                            CaptureLibraryCard(
                                item: item,
                                isSelected: selectedCaptureID == item.id,
                                select: { selectCapture(item) }
                            )
                        }
                    }
                    .padding(10)
                }
            }
        }
        .navigationTitle("Recents")
    }

    private var libraryHeader: some View {
        HStack {
            Text(recentCaptures.isEmpty ? "No saves" : "\(recentCaptures.count) saved")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(phase.isBusy)
            .help("Refresh captures")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct CaptureLibraryCard: View {
    let item: RecentCaptureItem
    let isSelected: Bool
    let select: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 6) {
                Image(nsImage: item.image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(height: 72)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(
                                isSelected ? Color.red : Color(.quaternaryLabelColor),
                                lineWidth: isSelected ? 2 : 0.5
                            )
                    }
                    .shadow(
                        color: .black.opacity(isHovered ? 0.18 : 0.06),
                        radius: isHovered ? 6 : 2,
                        y: 1
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.capturedAt, format: .relative(presentation: .named))
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Text(item.dimensionsText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(6)
        .background(
            isSelected
                ? Color.red.opacity(0.08)
                : (isHovered ? Color(.selectedContentBackgroundColor).opacity(0.06) : .clear),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
