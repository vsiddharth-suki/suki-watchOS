import Foundation

@Observable
@MainActor
final class ScheduleViewModel {
    var selectedDate = Date()
    var appointments: [Appointment] = []
    var isLoading = false
    var errorMessage: String?

    private let scheduleService = ScheduleService()

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            appointments = try await scheduleService.loadSchedule(for: selectedDate, forceEMRRefresh: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
