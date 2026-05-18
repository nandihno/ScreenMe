import SwiftUI

struct CapturePreviewView: View {
    let capture: CapturedImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.08))

            if let capture {
                GeometryReader { proxy in
                    Image(nsImage: capture.image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.height
                        )
                        .accessibilityLabel("Latest screenshot preview")
                }
                .padding(18)
            } else {
                EmptyPreviewState()
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary)
        }
    }
}

private struct EmptyPreviewState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.dashed")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 5) {
                Text("No capture yet")
                    .font(.title3.weight(.semibold))

                Text("Use Capture to select a screen region.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
