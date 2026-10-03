import Foundation

@Observable
@MainActor
final class HomeViewModel {
    var appointments: [Appointment] = []
    var recentNotes: [HomeRecentNote] = []
    var isLoading = false
    var isLoadingRecentNotes = false
    var errorMessage: String?
    var recentNotesError: String?

    private let scheduleService = ScheduleService()
    private let recentNotesService = RecentNotesService()
    private let userProfileService = UserProfileService()
    private var didForceRefresh = false

    func loadToday() async {
        await refreshWelcomeProfileIfNeeded()
        isLoading = true
        isLoadingRecentNotes = true
        errorMessage = nil
        recentNotesError = nil
        defer {
            isLoading = false
            isLoadingRecentNotes = false
        }

        let force = !didForceRefresh
        didForceRefresh = true

        async let scheduleTask: Void = loadSchedule(forceEMRRefresh: force)
        async let recentTask: Void = loadRecentNotes()
        _ = await (scheduleTask, recentTask)
    }

    private func loadSchedule(forceEMRRefresh: Bool) async {
        do {
            appointments = try await scheduleService.loadSchedule(for: Date(), forceEMRRefresh: forceEMRRefresh)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadRecentNotes() async {
        do {
            recentNotes = try await recentNotesService.fetchHomeRecentNotes()
        } catch {
            recentNotes = []
            recentNotesError = error.localizedDescription
        }
    }

    private func refreshWelcomeProfileIfNeeded() async {
        guard SessionStore.shared.shouldRefreshWelcomeProfile else { return }
        try? await userProfileService.fetchAndApplyCurrentUser(onLogin: false)
    }
}
