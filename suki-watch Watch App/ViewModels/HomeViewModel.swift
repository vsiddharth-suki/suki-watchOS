import Foundation

@Observable
@MainActor
final class HomeViewModel {
    var appointments: [Appointment] = []
    var noteStatusByAppointmentId: [String: String] = [:]
    var recentNotes: [HomeRecentNote] = []
    var isLoading = false
    /// True while today's schedule is loading and there is no cached snapshot yet.
    var isLoadingTodaySchedule = false
    var isLoadingRecentNotes = false
    var errorMessage: String?
    var recentNotesError: String?

    private let scheduleService = ScheduleService()
    private let recentNotesService = RecentNotesService()
    private let userProfileService = UserProfileService()
    private var didForceRefresh = false

    func loadToday() async {
        await SessionStore.shared.refreshEMRMembership()
        await refreshWelcomeProfileIfNeeded()
        let hadScheduleCache = ScheduleAppointmentCache.hasSnapshot(for: Date())
        applyCachedScheduleIfAvailable()

        isLoadingTodaySchedule = !hadScheduleCache
        isLoading = isLoadingTodaySchedule
        isLoadingRecentNotes = true
        errorMessage = nil
        recentNotesError = nil
        defer {
            isLoadingTodaySchedule = false
            isLoading = false
            isLoadingRecentNotes = false
        }

        let session = SessionStore.shared
        let forceEMR = session.belongsToEMR && !didForceRefresh && appointments.isEmpty
        if session.belongsToEMR, !didForceRefresh {
            didForceRefresh = true
        }

        async let scheduleTask: Void = loadSchedule(forceEMRRefresh: forceEMR)
        async let recentTask: Void = loadRecentNotes()
        _ = await (scheduleTask, recentTask)
    }

    private func loadSchedule(forceEMRRefresh: Bool) async {
        do {
            appointments = try await scheduleService.loadSchedule(for: Date(), forceEMRRefresh: forceEMRRefresh)
            await refreshNoteStatusForToday()
            persistTodaySnapshot()
        } catch {
            if appointments.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    func noteStatus(for appointmentId: String) -> String? {
        noteStatusByAppointmentId[appointmentId]
    }

    private static let homeScheduleDisplayLimit = 5

    /// Today's schedule on home — excludes submitted notes; capped for the home card.
    var homeScheduleAppointments: [Appointment] {
        Array(
            appointments
                .filter { !isSubmittedScheduleAppointment(appointmentId: $0.id) }
                .prefix(Self.homeScheduleDisplayLimit)
        )
    }

    private func isSubmittedScheduleAppointment(appointmentId: String) -> Bool {
        AppointmentNoteStatusPresentation.from(raw: noteStatusByAppointmentId[appointmentId]) == .submitted
    }

    private func applyCachedScheduleIfAvailable() {
        guard let cached = ScheduleAppointmentCache.snapshot(for: Date()) else { return }
        appointments = cached.appointments
        noteStatusByAppointmentId = cached.noteStatusByAppointmentId
        errorMessage = nil
    }

    private func persistTodaySnapshot() {
        ScheduleAppointmentCache.store(
            appointments: appointments,
            noteStatusByAppointmentId: noteStatusByAppointmentId,
            for: Date()
        )
    }

    private func refreshNoteStatusForToday() async {
        let ids = appointments.map(\.id)
        guard !ids.isEmpty else { return }
        do {
            noteStatusByAppointmentId = try await scheduleService.fetchNoteStatus(appointmentIds: ids)
            persistTodaySnapshot()
        } catch {
            // Keep cached statuses on failure.
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
