import SwiftUI

/// Blocks interaction and shows progress for long-running operations.
struct InProgressOverlay: View {
    var message: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 8) {
                ProgressView()
                if let message, !message.isEmpty {
                    Text(message)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                }
            }
            .padding(12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "In progress")
    }
}
