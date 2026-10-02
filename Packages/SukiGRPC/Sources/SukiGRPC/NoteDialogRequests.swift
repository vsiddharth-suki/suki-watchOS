import Foundation
import SwiftProtobuf

enum NoteDialogRequests {
    static func freshDialogRequest() -> Suki_Pb_S2_DialogRequest {
        var request = Suki_Pb_S2_DialogRequest()
        request.requestTime = Google_Protobuf_Timestamp(date: Date())
        return request
    }

    static func uiContextRequest(uictx: Suki_Pb_S2_UIContext) -> Suki_Pb_S2_DialogRequest {
        var request = freshDialogRequest()
        request.uiContext = uictx
        return request
    }

    static func fetchComposition(
        compositionID: String,
        organizationID: String,
        asNote: Bool = false
    ) -> Suki_Pb_S2_DialogRequest {
        var request = freshDialogRequest()
        var fetchCompRequest = Suki_Pb_S2_GetCompositionOrNoteRequest()
        fetchCompRequest.id = compositionID
        fetchCompRequest.organizationID = organizationID
        fetchCompRequest.requestType = asNote ? .note : .composition
        request.getCompositionOrNoteRequest = fetchCompRequest
        return request
    }

    static func createCompositionCreationRequest() -> Suki_Pb_S2_DialogRequest {
        var request = freshDialogRequest()
        var createCompReq = Suki_Pb_S2_Request()
        createCompReq.requestType = .createNote
        request.userRequest = createCompReq
        return request
    }

    static func createCompositionWithPatient(
        compositionID: String,
        noteTypeID: String,
        patientID: String,
        appointmentID: String
    ) -> Suki_Pb_S2_DialogRequest {
        var request = freshDialogRequest()
        var compReq = Suki_Pb_S2_Request()
        compReq.requestType = .createNoteWithNotetypePatient
        compReq.compositionID = compositionID
        compReq.notetypeID = noteTypeID
        compReq.patientID = patientID
        compReq.appointmentID = appointmentID
        compReq.fromPatientList = true
        request.userRequest = compReq
        return request
    }

    static func sectionTypedChanges(
        section: Learningmotors_Pb_Composer_SectionS2,
        compositionID: String,
        noteTypeID: String
    ) -> Suki_Pb_S2_DialogRequest {
        var request = freshDialogRequest()
        var typingReq = Suki_Pb_S2_Request()
        typingReq.requestType = .updateSection
        typingReq.sectionData = section
        typingReq.compositionID = compositionID
        typingReq.notetypeID = noteTypeID
        typingReq.sectionID = section.id
        request.userRequest = typingReq
        return request
    }

    static func initialNoteSubmission(composition: Learningmotors_Pb_Composer_Composition) -> Suki_Pb_S2_DialogRequest {
        var request = freshDialogRequest()
        var submitNoteRequest = Suki_Pb_S2_Request()
        submitNoteRequest.requestType = .initialNoteSubmission
        submitNoteRequest.patientID = composition.metadata.patient.id
        submitNoteRequest.appointmentID = composition.metadata.appointment.id
        submitNoteRequest.compositionID = composition.id
        request.userRequest = submitNoteRequest
        return request
    }

    static func tryAllDestinations(for composition: Learningmotors_Pb_Composer_Composition) -> Bool {
        let destinations = composition.metadata.submissionInformation.destinations
        let primaryTypeIsNonDocument = !destinations.isEmpty ? destinations[0] != .document : true
        let secondaryTypeIsDocument = destinations.count > 1 ? destinations[1] == .document : false
        if primaryTypeIsNonDocument, secondaryTypeIsDocument {
            return false
        }
        return true
    }

    static func submitCompositionFinal(
        composition: Learningmotors_Pb_Composer_Composition,
        organizationID: String,
        bypassQA: Bool,
        tryAllDestinations: Bool
    ) -> Suki_Pb_S2_DialogRequest {
        var request = freshDialogRequest()
        var submitNoteRequest = Suki_Pb_Sms_SubmitCompositionRequest()
        submitNoteRequest.actor = .user
        submitNoteRequest.bypassQa = bypassQA
        submitNoteRequest.waitForFinalText = false
        submitNoteRequest.id = composition.id
        submitNoteRequest.organizationID = organizationID
        submitNoteRequest.tryAllDestinations = tryAllDestinations
        submitNoteRequest.isSignedOff = false
        submitNoteRequest.requestSentTime = request.requestTime
        request.submitCompositionRequest = submitNoteRequest
        return request
    }

    static func submissionSuccessful(compositionID: String) -> Suki_Pb_S2_DialogRequest {
        var request = freshDialogRequest()
        var successSubmit = Suki_Pb_S2_Request()
        successSubmit.requestType = .compositionSubmissionSuccessufl
        successSubmit.compositionID = compositionID
        request.userRequest = successSubmit
        return request
    }
}

extension Suki_Pb_S2_DialogRequest {
    func asAssistRequest() -> Suki_Pb_SukiServer_V1_AssistRequest {
        var assist = Suki_Pb_SukiServer_V1_AssistRequest()
        assist.legacyRequest = self
        return assist
    }
}

extension Suki_Pb_S2_UIContext {
    static func watchNoteContext(
        sessionID: String,
        organizationID: String,
        userID: String,
        compositionID: String,
        noteTypeID: String,
        patientID: String,
        view: Suki_Pb_S2_UIContext.View = .note
    ) -> Suki_Pb_S2_UIContext {
        var uictx = Suki_Pb_S2_UIContext()
        uictx.view = view
        uictx.sessionID = sessionID
        uictx.organizationID = organizationID
        uictx.userID = userID
        uictx.compositionID = compositionID
        uictx.notetypeID = noteTypeID
        uictx.patientID = patientID
        uictx.userAgent = "Suki-watchOS"
        uictx.uiContextTime = Google_Protobuf_Timestamp(date: Date())
        return uictx
    }
}
