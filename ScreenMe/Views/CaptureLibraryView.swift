import SwiftUI

struct CaptureLibraryView: View {
    let recentCaptures: [RecentCaptureItem]
    let selectedCaptureID: URL?
    let phase: CapturePhase
    let refresh: () -> Void
    let selectCapture: (RecentCaptureItem) -> Void
    let openForAnnotation: (RecentCaptureItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 170, maximum: 230), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Recent Captures")
                        .font(.headline)

                    Text("\(recentCaptures.count) of the last 10 saved PNGs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: refresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(phase.isBusy)
            }

            if recentCaptures.isEmpty {
                EmptyLibraryState()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                        ForEach(recentCaptures) { item in
                            CaptureLibraryCard(
                                item: item,
                                isSelected: selectedCaptureID == item.id,
                                select: { selectCapture(item) },
                                open: { openForAnnotation(item) }
                            )
                        }
                    }
                    .padding(2)
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary)
        }
    }
}

private struct CaptureLibraryCard: View {
    let item: RecentCaptureItem
    let isSelected: Bool
    let select: () -> Void
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button(action: select) {
                Image(nsImage: item.image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 108)
                    .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.red, lineWidth: 2)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.quaternary)
                        }
                    }
            }
            .buttonStyle(.plain)
            .onTapGesture(count: 2, perform: open)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.fileName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("\(item.dimensionsText) · \(Self.dateFormatter.string(from: item.capturedAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button(action: open) {
                Label("Annotate", systemImage: "pencil.and.outline")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(.background.opacity(isSelected ? 0.72 : 0.42), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.red.opacity(0.58))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary)
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct EmptyLibraryState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("No recent captures")
                    .font(.title3.weight(.semibold))

                Text("Captured PNGs will appear here after they are saved.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
