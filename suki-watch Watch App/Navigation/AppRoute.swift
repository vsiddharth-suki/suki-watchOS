import Foundation

enum AppRoute: Hashable {
    case schedule
    case search
    case patientProfile(patientId: String, patientName: String, appointmentId: String?)
    case note(noteId: String, patientId: String?, patientName: String?)
    case ambient(AmbientLaunchContext)
}

struct AmbientLaunchContext: Hashable {
    var patientId: String?
    var patientName: String?
    var appointmentId: String?
    var noteId: String?
    var startWithoutPatient: Bool
}
