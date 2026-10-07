import SwiftUI

struct AmbientGeneratingProgressBar: View {
    let progress: Double
    let text: String

    var body: some View {
        // Spinner is overlaid so its layout size does not push the bar down.
        // `scaleEffect` only changes drawing, not the ProgressView's frame.
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            GeneratingLinearProgressBar(progress: progress)
        }
        .overlay(alignment: .topTrailing) {
            ProgressView()
                .controlSize(.mini)
                .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text), \(Int((progress * 100).rounded())) percent")
    }
}

private struct GeneratingLinearProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(max(progress, 0), 1)
            let fillWidth = geometry.size.width * clamped
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                Capsule()
                    .fill(Color.primary)
                    .frame(width: fillWidth)
                    .animation(.easeInOut, value: progress)
            }
        }
        .frame(height: 6)
    }
}
