import SwiftUI

struct RecordingMicView: View {
    var compact: Bool = false

    @State private var isPulsing = false

    private var circleSize: CGFloat { compact ? 28 : 44 }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.25))
                .frame(width: circleSize, height: circleSize)
                .scaleEffect(isPulsing ? 1.35 : 0.85)
                .opacity(isPulsing ? 0.35 : 0.7)

            Image(systemName: "mic.fill")
                .font(compact ? .caption : .title3)
                .foregroundStyle(.red)
                .scaleEffect(isPulsing ? 1.1 : 0.95)
        }
        .frame(maxWidth: compact ? nil : .infinity)
        .padding(.vertical, compact ? 0 : 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
