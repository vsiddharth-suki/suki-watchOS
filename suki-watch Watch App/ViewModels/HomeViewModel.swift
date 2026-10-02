import Foundation

@Observable
@MainActor
final class HomeViewModel {
    var appointments: [Appointment] = []
    var isLoading = false
    var errorMessage: String?

    private let scheduleService = ScheduleService()
    private let userProfileService = UserProfileService()
    private var didForceRefresh = false

    func loadToday() async {
        await refreshWelcomeProfileIfNeeded()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let force = !didForceRefresh
            didForceRefresh = true
            appointments = try await scheduleService.loadSchedule(for: Date(), forceEMRRefresh: force)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshWelcomeProfileIfNeeded() async {
        let first = SessionStore.shared.userFirstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard first.isEmpty else { return }
        try? await userProfileService.fetchAndApplyCurrentUser(onLogin: false)
    }
}
