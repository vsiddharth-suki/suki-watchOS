import Foundation

@Observable
@MainActor
final class HomeViewModel {
    var appointments: [Appointment] = []
    var noteStatusByAppointmentId: [String: String] = [:]
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
        applyCachedScheduleIfAvailable()

        let showScheduleLoader = appointments.isEmpty
        isLoading = showScheduleLoader
        isLoadingRecentNotes = true
        errorMessage = nil
        recentNotesError = nil
        defer {
            isLoading = false
            isLoadingRecentNotes = false
        }

        let forceEMR = !didForceRefresh && appointments.isEmpty
        if !didForceRefresh {
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

    /// Today's schedule on home — excludes appointments with a submitted note (green check).
    var homeScheduleAppointments: [Appointment] {
        appointments.filter { appointment in
            !isSubmittedScheduleAppointment(appointmentId: appointment.id)
        }
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
