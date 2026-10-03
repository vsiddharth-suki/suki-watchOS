import Foundation

@Observable
@MainActor
final class ScheduleViewModel {
    var selectedDate = Date()
    var appointments: [Appointment] = []
    /// Appointment id → note status from `GET /notes/status`.
    var noteStatusByAppointmentId: [String: String] = [:]
    var isLoading = false
    /// True while any schedule fetch (initial or manual) is in flight.
    var isRefreshing = false
    /// Becomes true after the first `load()` finishes (success or failure).
    var hasCompletedInitialLoad = false
    var errorMessage: String?

    private let scheduleService = ScheduleService()

    /// Loads schedule for `selectedDate`. Uses in-memory cache for instant UI when returning from profile.
    func load(forceEMRRefresh: Bool? = nil) async {
        isRefreshing = true
        let hadCache = ScheduleAppointmentCache.hasSnapshot(for: selectedDate)
        applyCachedSnapshotIfAvailable()

        let shouldForceEMR = forceEMRRefresh ?? appointments.isEmpty
        let showBlockingLoader = !hadCache
        if showBlockingLoader {
            isLoading = true
        }
        errorMessage = nil
        defer {
            isRefreshing = false
            hasCompletedInitialLoad = true
            if showBlockingLoader {
                isLoading = false
            }
        }

        do {
            appointments = try await scheduleService.loadSchedule(
                for: selectedDate,
                forceEMRRefresh: shouldForceEMR
            )
            await refreshNoteStatus()
            persistSnapshot()
        } catch {
            if appointments.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    func noteStatus(for appointmentId: String) -> String? {
        noteStatusByAppointmentId[appointmentId]
    }

    private func applyCachedSnapshotIfAvailable() {
        guard let cached = ScheduleAppointmentCache.snapshot(for: selectedDate) else { return }
        appointments = cached.appointments
        noteStatusByAppointmentId = cached.noteStatusByAppointmentId
        errorMessage = nil
    }

    private func persistSnapshot() {
        ScheduleAppointmentCache.store(
            appointments: appointments,
            noteStatusByAppointmentId: noteStatusByAppointmentId,
            for: selectedDate
        )
    }

    private func refreshNoteStatus() async {
        let ids = appointments.map(\.id)
        guard !ids.isEmpty else { return }
        do {
            noteStatusByAppointmentId = try await scheduleService.fetchNoteStatus(appointmentIds: ids)
            persistSnapshot()
        } catch {
            // Keep cached statuses on failure.
        }
    }
}
