import SwiftUI

enum AppColors {
    /// Matches iOS `Neutral_White_Flexi` screen surfaces in light mode.
    static let screenBackground = Color.white
    static let noteSectionFill = Color(white: 0.96)
}

private struct SukiScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.screenBackground.ignoresSafeArea())
    }
}

extension View {
    /// White root background and light list chrome (use with `.preferredColorScheme(.light)`).
    func sukiScreenBackground() -> some View {
        modifier(SukiScreenBackgroundModifier())
    }
}
