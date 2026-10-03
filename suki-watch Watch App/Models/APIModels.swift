import Foundation

// MARK: - Appointments

struct AppointmentsResponse: Codable {
    var appointments: [Appointment] = []

    enum CodingKeys: String, CodingKey {
        case appointments = "results"
    }
}

struct Appointment: Codable, Identifiable, Hashable {
    var id: String
    var startsAt: String?
    var type: String?
    var reason: String?
    var patient: PatientSummary?
    var compositionIds: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case startsAt
        case type
        case reason
        case patient
        case compositionIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        startsAt = try c.decodeIfPresent(String.self, forKey: .startsAt)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        patient = try c.decodeIfPresent(PatientSummary.self, forKey: .patient)
        compositionIds = try c.decodeIfPresent([String].self, forKey: .compositionIds)
    }
}

struct PatientSummary: Codable, Hashable, Identifiable {
    var id: String
    var mrn: String?
    var person: PersonName?

    var displayName: String {
        person?.fullName ?? "Patient"
    }
}

struct PersonName: Codable, Hashable {
    var firstName: String?
    var lastName: String?
    var preferredName: String?

    enum CodingKeys: String, CodingKey {
        case firstName
        case lastName
        case preferredName
        case first_name
        case last_name
    }

    init(firstName: String?, lastName: String?, preferredName: String?) {
        self.firstName = firstName
        self.lastName = lastName
        self.preferredName = preferredName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
            ?? container.decodeIfPresent(String.self, forKey: .first_name)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
            ?? container.decodeIfPresent(String.self, forKey: .last_name)
        preferredName = try container.decodeIfPresent(String.self, forKey: .preferredName)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(firstName, forKey: .firstName)
        try container.encodeIfPresent(lastName, forKey: .lastName)
        try container.encodeIfPresent(preferredName, forKey: .preferredName)
    }

    var fullName: String {
        let parts = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "Patient" : parts.joined(separator: " ")
    }
}

// MARK: - Patients search

struct APIListResponse<T: Codable>: Codable {
    var count: Int?
    var results: [T]?
}

struct PatientSearchResult: Codable, Identifiable {
    var id: String?
    var mrn: String?
    var person: PersonName?

    var stableId: String { id ?? UUID().uuidString }

    var displayName: String { person?.fullName ?? "Patient" }
}

// MARK: - Notes list

struct NotesListResponse: Codable {
    var count: Int
    var results: [NoteListItem]
}

struct UnfinishedNotesResponse: Codable {
    var count: Int?
    var results: [NoteListItem]
}

struct InProgressAmbientSessionsResponse: Decodable {
    var sessions: [InProgressAmbientSession]?
    var patients: [AmbientSessionPatient]?
}

struct InProgressAmbientSession: Decodable {
    var noteId: String?
    var ambientSessionId: String?
    var patientId: String?
    var appointmentId: String?
    var notetypeId: String?
    var startTime: String?
    var isNoteCreated: Bool?
    var isAutoSubmit: Bool?
    var patientLabel: String?

    enum CodingKeys: String, CodingKey {
        case noteId = "note_id"
        case ambientSessionId = "ambient_session_id"
        case patientId = "patient_id"
        case appointmentId = "appointment_id"
        case notetypeId = "notetype_id"
        case startTime = "start_time"
        case isNoteCreated = "is_note_created"
        case isAutoSubmit = "is_auto_submit"
        case patientLabel = "patient_label_for_composition"
    }
}

struct AmbientSessionPatient: Decodable, Identifiable {
    var id: String?
    var person: PersonName?

    var displayName: String {
        person?.fullName ?? "Patient"
    }
}

struct HomeRecentNote: Identifiable, Hashable {
    var id: String
    var noteId: String?
    var patientId: String?
    var patientName: String?
    var headline: String
    var subtitle: String
    var timeLabel: String
    var isIncomplete: Bool
}

struct NoteListItem: Codable, Identifiable, Hashable {
    var id: String?
    var noteId: String?
    var userId: String?
    var createdAt: String?
    var compositionCreatedAt: String?
    var updatedAt: String?
    var metadata: NoteListMetadata?

    enum CodingKeys: String, CodingKey {
        case id
        case noteId
        case userId
        case createdAt
        case compositionCreatedAt = "composition_created_at"
        case updatedAt
        case metadata
    }

    var stableId: String {
        [id, noteId].compactMap { $0 }.first { !$0.isEmpty } ?? UUID().uuidString
    }

    var title: String {
        metadata?.name ?? "Note"
    }

    var status: String? { metadata?.status }

    var isUnfinished: Bool {
        normalizedStatus == "INCOMPLETE" || normalizedStatus == "AMBIENT_IN_PROGRESS"
    }

    var isAmbientInProgress: Bool {
        normalizedStatus == "AMBIENT_IN_PROGRESS"
    }

    /// iOS unfinished list sort: appointment date of service when linked, else composition created.
    var unfinishedSortDate: Date {
        if let appointmentDate = metadata?.appointment?.startsAt,
           !appointmentDate.isEmpty,
           let parsed = NoteDateClassification.parseCreatedAt(appointmentDate) {
            return parsed
        }
        return NoteDateClassification.parseCreatedAt(compositionCreatedDateString) ?? .distantPast
    }

    var dateOfServiceLabel: String {
        DateRangeFormatter.noteServiceDateLabel(iso: effectiveDateString)
    }

    var isSubmitted: Bool {
        Self.isSubmittedStatus(normalizedStatus)
    }

    /// Shared with note detail (`compositionOrNote`) status checks.
    static func isSubmittedStatus(_ status: String?) -> Bool {
        let normalized = (status ?? "").uppercased()
        switch normalized {
        case "SUBMITTED_TO_EMR", "IMPORTED_FROM_EMR":
            return true
        case "INCOMPLETE", "AMBIENT_IN_PROGRESS", "":
            return false
        default:
            return normalized != "INCOMPLETE" && normalized != "AMBIENT_IN_PROGRESS"
        }
    }

    /// iOS `PriorNotePresenter` sorts by composition `createdDate`.
    var compositionCreatedDateString: String? {
        if let createdAt, !createdAt.isEmpty { return createdAt }
        if let compositionCreatedAt, !compositionCreatedAt.isEmpty { return compositionCreatedAt }
        return nil
    }

    var sortDate: Date? {
        NoteDateClassification.parseCreatedAt(effectiveDateString)
    }

    /// Appointment start when present, else composition created — matches iOS `getDateSourceType` for Athena.
    var effectiveDateString: String? {
        if let appointmentDate = metadata?.appointment?.startsAt, !appointmentDate.isEmpty {
            return appointmentDate
        }
        if let createdAt, !createdAt.isEmpty { return createdAt }
        if let compositionCreatedAt, !compositionCreatedAt.isEmpty { return compositionCreatedAt }
        if let updatedAt, !updatedAt.isEmpty { return updatedAt }
        return nil
    }

    func shouldShowOnPatientProfile(currentUserId: String?) -> Bool {
        let status = normalizedStatus
        if status == "IMPORTED_FROM_EMR" { return true }

        let ownerId = metadata?.user?.id ?? userId
        if let currentUserId, !currentUserId.isEmpty, ownerId == currentUserId {
            return true
        }
        if let ownerId, !ownerId.isEmpty, ownerId != currentUserId {
            // Athena / EMR: hide other clinicians' submitted notes on patient profile.
            if status == "SUBMITTED_TO_EMR" { return false }
            return false
        }
        // Missing owner metadata — keep note visible (common for own submitted notes).
        return true
    }

    private var normalizedStatus: String {
        (status ?? "").uppercased()
    }
}

struct NoteListMetadata: Codable, Hashable {
    var name: String?
    var status: String?
    var noteTypeId: String?
    var patient: PatientSummary?
    var user: NoteListUser?
    var appointment: NoteListAppointment?
    var patientLabel: String?

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case noteTypeId
        case patient
        case user
        case appointment
        case patientLabel
    }
}

struct NoteListUser: Codable, Hashable {
    var id: String?
}

struct NoteListAppointment: Codable, Hashable {
    var startsAt: String?
}

// MARK: - Note detail

struct DeleteCompositionResponse: Decodable {
    var success: Bool?
}

struct CompositionOrNoteResponse: Codable {
    var type: String?
    var data: CompositionOrNoteData?
}

struct CompositionOrNoteData: Codable {
    var id: String?
    var noteId: String?
    var compositionId: String?
    var metadata: CompositionOrNoteMetadata?
    var sections: [NoteSectionModel]?
    var sectionsS2: [NoteSectionModel]?
    var readOnly: Bool?
}

struct CompositionOrNoteMetadata: Codable {
    var name: String?
    var status: String?
    var noteTypeId: String?
    var patient: PatientSummary?
    var appointment: CompositionAppointmentRef?
}

struct CompositionAppointmentRef: Codable, Hashable {
    var id: String?
    var startsAt: String?
}

struct NoteSectionModel: Codable, Identifiable, Hashable {
    var id: String?
    var name: String?
    var content: String?
    var plainText: String?

    var stableId: String { id ?? name ?? UUID().uuidString }

    var bodyText: String {
        let text = plainText ?? content ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - EMR refresh

struct RefreshEMRAppointmentBody: Codable {
    var toDate: String
    var fromDate: String
    var forceRefresh: Bool
    var emrAccessToken: String?
}

// MARK: - Note types

struct NoteTypesResponse: Codable {
    var count: Int?
    var noteTypes: [NoteTypeItem]?

    enum CodingKeys: String, CodingKey {
        case count
        case noteTypes = "results"
    }
}

struct NoteTypeItem: Codable, Identifiable, Hashable {
    var id: String
    var name: String
}

// MARK: - Ambient

struct AmbientSessionMetadataBody: Codable {
    var flowContext: AmbientFlowContext?
    var sessionContext: AmbientSessionContext?
    var patientContext: AmbientPatientContext?
    var appointmentContext: AmbientAppointmentContext?
    var compositionContext: AmbientCompositionContext?

    enum CodingKeys: String, CodingKey {
        case flowContext = "flow_context"
        case sessionContext = "session_context"
        case patientContext = "patient_context"
        case appointmentContext = "appointment_context"
        case compositionContext = "composition_context"
    }
}

struct AmbientFlowContext: Codable {
    var noteTypeId: String?
    var noteId: String?
    var visitTypeId: String?

    enum CodingKeys: String, CodingKey {
        case noteTypeId = "note_type_id"
        case noteId = "note_id"
        case visitTypeId = "visit_type_id"
    }
}

struct AmbientSessionContext: Codable {
    var offline: Bool
    var autoSubmitToEMR: Bool
    var deviceInfo: String
    var onDeviceTranscription: Bool?

    enum CodingKeys: String, CodingKey {
        case offline
        case autoSubmitToEMR = "auto_submit_to_emr"
        case deviceInfo = "device_info"
        case onDeviceTranscription = "on_device_transcription"
    }
}

struct AmbientPatientContext: Codable {
    var patientId: String?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
    }
}

struct AmbientAppointmentContext: Codable {
    var appointmentId: String?

    enum CodingKeys: String, CodingKey {
        case appointmentId = "appointment_id"
    }
}

struct AmbientCompositionContext: Codable {
    var patientLabel: String?

    enum CodingKeys: String, CodingKey {
        case patientLabel = "patient_label"
    }
}

struct AmbientSessionMetadataResponse: Codable {
    var ambientSessionId: String?
    var code: Int?
    var message: String?
}

struct FetchUploadURLBody: Codable {
    var userId: String
    var scope: UploadScope
    var metadata: UploadMetadata
}

struct UploadScope: Codable {
    var organizationId: String
}

struct UploadMetadata: Codable {
    var payattentionSessionIdentifier: String

    enum CodingKeys: String, CodingKey {
        case payattentionSessionIdentifier = "payattention_session_identifier"
    }
}

struct FetchUploadURLResponse: Codable {
    var url: String
    var fileName: String?
}

// MARK: - Current user (`POST /auth/me`, same as iOS `UserClient.getUser`)

struct AuthMeRequestBody: Encodable {
    var userId: String
    var onLogin: Bool
}

struct CurrentUserResponse: Decodable {
    var user: CurrentUser
}

struct CurrentUser: Decodable {
    var person: CurrentUserPerson?
}

struct CurrentUserPerson: Decodable {
    var prefix: String?
    var firstName: String?
    var lastName: String?

    enum CodingKeys: String, CodingKey {
        case prefix
        case firstName
        case lastName
        case first_name
        case last_name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prefix = try container.decodeIfPresent(String.self, forKey: .prefix)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
            ?? container.decodeIfPresent(String.self, forKey: .first_name)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
            ?? container.decodeIfPresent(String.self, forKey: .last_name)
    }
}
