import SwiftUI

struct AmbientGeneratingProgressBar: View {
    let progress: Double
    let text: String

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                ProgressView()
                    .scaleEffect(0.7)
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.primary)
                .animation(.easeInOut, value: progress)
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text), \(Int((progress * 100).rounded())) percent")
    }
}
