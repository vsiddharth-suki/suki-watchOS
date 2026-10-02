import Foundation
import GRPC
import NIO
import SwiftProtobuf

public struct NoteSubmitCredentials: Sendable {
    public let jwtToken: String
    public let accessToken: String
    public let userId: String
    public let organizationId: String
    public let sessionId: String

    public init(
        jwtToken: String,
        accessToken: String,
        userId: String,
        organizationId: String,
        sessionId: String
    ) {
        self.jwtToken = jwtToken
        self.accessToken = accessToken
        self.userId = userId
        self.organizationId = organizationId
        self.sessionId = sessionId
    }
}

public struct NoteSubmitSection: Sendable {
    public let id: String
    public let name: String
    public let plainText: String

    public init(id: String, name: String, plainText: String) {
        self.id = id
        self.name = name
        self.plainText = plainText
    }
}

public struct NoteSubmitPayload: Sendable {
    public let compositionId: String
    public let noteTypeId: String
    public let patientId: String
    public let appointmentId: String
    public let sections: [NoteSubmitSection]

    public init(
        compositionId: String,
        noteTypeId: String,
        patientId: String,
        appointmentId: String = "",
        sections: [NoteSubmitSection]
    ) {
        self.compositionId = compositionId
        self.noteTypeId = noteTypeId
        self.patientId = patientId
        self.appointmentId = appointmentId
        self.sections = sections
    }
}

public struct NoteCreatePayload: Sendable {
    public let noteTypeId: String
    public let patientId: String
    public let appointmentId: String

    public init(noteTypeId: String, patientId: String, appointmentId: String = "") {
        self.noteTypeId = noteTypeId
        self.patientId = patientId
        self.appointmentId = appointmentId
    }
}

public enum NoteSubmitError: Error, LocalizedError {
    case missingCredentials
    case streamFailed(String)
    case submissionFailed(String)
    case noteCreationFailed(String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Missing sign-in credentials."
        case .streamFailed(let message):
            return message
        case .submissionFailed(let message):
            return message.isEmpty ? "Note submission failed." : message
        case .noteCreationFailed(let message):
            return message.isEmpty ? "Could not create note." : message
        case .timedOut:
            return "Request timed out."
        }
    }
}

public enum NoteSubmitGRPCClient {
    public static let defaultHost = "suki-server.suki-stage.com"
    public static let defaultPort = 443

    public static func createNote(
        payload: NoteCreatePayload,
        credentials: NoteSubmitCredentials,
        host: String = defaultHost,
        port: Int = defaultPort,
        timeoutSeconds: UInt64 = 90
    ) async throws -> String {
        try validate(credentials)
        return try await runAssist(
            credentials: credentials,
            host: host,
            port: port,
            timeoutSeconds: timeoutSeconds
        ) { stream, queue, finish in
            let uictx = Suki_Pb_S2_UIContext.watchNoteContext(
                sessionID: credentials.sessionId,
                organizationID: credentials.organizationId,
                userID: credentials.userId,
                compositionID: "",
                noteTypeID: payload.noteTypeId,
                patientID: payload.patientId,
                view: .profile
            )
            queue.async {
                stream.sendMessage(NoteDialogRequests.uiContextRequest(uictx: uictx).asAssistRequest(), promise: nil)
                stream.sendMessage(NoteDialogRequests.createCompositionCreationRequest().asAssistRequest(), promise: nil)
            }
        } onLegacyResponse: { dialog, stream, queue, state, finish in
            switch dialog.response {
            case .serverResponse(let serverResponse):
                if serverResponse.hasCompositionCreatedResponse {
                    let compositionID = serverResponse.compositionCreatedResponse.compositionID
                    guard !compositionID.isEmpty else {
                        finish(.failure(NoteSubmitError.noteCreationFailed("Empty composition id.")))
                        return
                    }
                    state.createdCompositionID = compositionID
                    queue.async {
                        stream.sendMessage(
                            NoteDialogRequests.createCompositionWithPatient(
                                compositionID: compositionID,
                                noteTypeID: payload.noteTypeId,
                                patientID: payload.patientId,
                                appointmentID: payload.appointmentId
                            ).asAssistRequest(),
                            promise: nil
                        )
                    }
                } else if
                    serverResponse.hasCompositionResponse,
                    serverResponse.compositionResponse.hasNoteComposition
                {
                    let noteID = serverResponse.compositionResponse.noteComposition.id
                    if noteID.isEmpty {
                        finish(.failure(NoteSubmitError.noteCreationFailed("Empty note id.")))
                    } else {
                        queue.async {
                            stream.sendEnd(promise: nil)
                        }
                        finish(.success(noteID))
                    }
                }
            case .error(let error):
                finish(.failure(NoteSubmitError.noteCreationFailed(error.reason)))
            default:
                break
            }
        }
    }

    public static func submit(
        payload: NoteSubmitPayload,
        credentials: NoteSubmitCredentials,
        host: String = defaultHost,
        port: Int = defaultPort,
        timeoutSeconds: UInt64 = 90
    ) async throws {
        try validate(credentials)
        _ = try await runAssist(
            credentials: credentials,
            host: host,
            port: port,
            timeoutSeconds: timeoutSeconds
        ) { stream, queue, _ in
            let uictx = Suki_Pb_S2_UIContext.watchNoteContext(
                sessionID: credentials.sessionId,
                organizationID: credentials.organizationId,
                userID: credentials.userId,
                compositionID: payload.compositionId,
                noteTypeID: payload.noteTypeId,
                patientID: payload.patientId
            )
            queue.async {
                stream.sendMessage(NoteDialogRequests.uiContextRequest(uictx: uictx).asAssistRequest(), promise: nil)
                stream.sendMessage(
                    NoteDialogRequests.fetchComposition(
                        compositionID: payload.compositionId,
                        organizationID: credentials.organizationId,
                        asNote: false
                    ).asAssistRequest(),
                    promise: nil
                )
            }
        } onLegacyResponse: { dialog, stream, queue, state, finish in
            switch dialog.response {
            case .getCompositionOrNoteResponse(let fetchResponse):
                handleFetchedCompositionForSubmit(
                    fetchResponse: fetchResponse,
                    payload: payload,
                    credentials: credentials,
                    stream: stream,
                    queue: queue,
                    state: state,
                    finish: finish
                )
            case .serverSubmitCompositionResponse(let submission):
                switch submission.submitCompositionResponseType {
                case .error:
                    finish(.failure(NoteSubmitError.submissionFailed(submission.submitCompositionResponseErrorMessage)))
                case .success:
                    let noteID = submission.submitCompositionResponse.noteID
                    if noteID.isEmpty {
                        finish(.failure(NoteSubmitError.submissionFailed("Empty note id in submission response.")))
                    } else {
                        queue.async {
                            stream.sendMessage(
                                NoteDialogRequests.submissionSuccessful(compositionID: payload.compositionId).asAssistRequest(),
                                promise: nil
                            )
                            stream.sendEnd(promise: nil)
                        }
                        finish(.success(noteID))
                    }
                default:
                    finish(.failure(NoteSubmitError.submissionFailed("Unexpected submission response.")))
                }
            case .error(let error):
                finish(.failure(NoteSubmitError.submissionFailed(error.reason)))
            default:
                break
            }
        }
    }

    private final class AssistState: @unchecked Sendable {
        var didPrepareSubmit = false
        var triedNoteFetch = false
        var createdCompositionID: String?
    }

    private static func handleFetchedCompositionForSubmit(
        fetchResponse: Suki_Pb_S2_GetCompositionOrNoteResponse,
        payload: NoteSubmitPayload,
        credentials: NoteSubmitCredentials,
        stream: BidirectionalStreamingCall<
            Suki_Pb_SukiServer_V1_AssistRequest,
            Suki_Pb_SukiServer_V1_AssistResponse
        >,
        queue: DispatchQueue,
        state: AssistState,
        finish: @escaping (Result<String, Error>) -> Void
    ) {
        var composition = fetchResponse.composition
        if composition.id.isEmpty, case .composition(let fetched)? = fetchResponse.compositionOrNote {
            composition = fetched
        }

        if composition.id.isEmpty, fetchResponse.compositionOrNote != nil, !state.triedNoteFetch {
            state.triedNoteFetch = true
            queue.async {
                stream.sendMessage(
                    NoteDialogRequests.fetchComposition(
                        compositionID: payload.compositionId,
                        organizationID: credentials.organizationId,
                        asNote: true
                    ).asAssistRequest(),
                    promise: nil
                )
            }
            return
        }

        guard !composition.id.isEmpty else {
            finish(.failure(NoteSubmitError.submissionFailed("Could not load note from server.")))
            return
        }
        guard !state.didPrepareSubmit else { return }
        state.didPrepareSubmit = true

        let noteTypeID = composition.metadata.notetypeID.isEmpty ? payload.noteTypeId : composition.metadata.notetypeID
        let sectionUpdates = payload.sections.filter { section in
            !section.id.isEmpty && section.id != "default-section"
        }

        let requests: [Suki_Pb_S2_DialogRequest] = {
            var messages: [Suki_Pb_S2_DialogRequest] = []
            for section in sectionUpdates {
                var protoSection = Learningmotors_Pb_Composer_SectionS2()
                protoSection.id = section.id
                protoSection.name = section.name
                protoSection.plainText = section.plainText
                messages.append(
                    NoteDialogRequests.sectionTypedChanges(
                        section: protoSection,
                        compositionID: composition.id,
                        noteTypeID: noteTypeID
                    )
                )
            }
            messages.append(NoteDialogRequests.initialNoteSubmission(composition: composition))
            messages.append(
                NoteDialogRequests.uiContextRequest(
                    uictx: Suki_Pb_S2_UIContext.watchNoteContext(
                        sessionID: credentials.sessionId,
                        organizationID: credentials.organizationId,
                        userID: credentials.userId,
                        compositionID: composition.id,
                        noteTypeID: noteTypeID,
                        patientID: composition.metadata.patient.id.isEmpty ? payload.patientId : composition.metadata.patient.id,
                        view: .submissionPanel
                    )
                )
            )
            messages.append(
                NoteDialogRequests.submitCompositionFinal(
                    composition: composition,
                    organizationID: credentials.organizationId,
                    bypassQA: true,
                    tryAllDestinations: NoteDialogRequests.tryAllDestinations(for: composition)
                )
            )
            return messages
        }()

        sendSequentially(requests, stream: stream, queue: queue, intervalMs: 120)
    }

    private static func sendSequentially(
        _ requests: [Suki_Pb_S2_DialogRequest],
        stream: BidirectionalStreamingCall<
            Suki_Pb_SukiServer_V1_AssistRequest,
            Suki_Pb_SukiServer_V1_AssistResponse
        >,
        queue: DispatchQueue,
        intervalMs: Int
    ) {
        for (index, request) in requests.enumerated() {
            let delay = DispatchTimeInterval.milliseconds(index * intervalMs)
            queue.asyncAfter(deadline: .now() + delay) {
                stream.sendMessage(request.asAssistRequest(), promise: nil)
            }
        }
    }

    private static func validate(_ credentials: NoteSubmitCredentials) throws {
        guard
            !credentials.jwtToken.isEmpty,
            !credentials.accessToken.isEmpty,
            !credentials.userId.isEmpty,
            !credentials.organizationId.isEmpty
        else {
            throw NoteSubmitError.missingCredentials
        }
    }

    @discardableResult
    private static func runAssist(
        credentials: NoteSubmitCredentials,
        host: String,
        port: Int,
        timeoutSeconds: UInt64,
        onStreamReady: @escaping (
            BidirectionalStreamingCall<Suki_Pb_SukiServer_V1_AssistRequest, Suki_Pb_SukiServer_V1_AssistResponse>,
            DispatchQueue,
            @escaping (Result<String, Error>) -> Void
        ) -> Void,
        onLegacyResponse: @escaping (
            Suki_Pb_S2_DialogResponse,
            BidirectionalStreamingCall<Suki_Pb_SukiServer_V1_AssistRequest, Suki_Pb_SukiServer_V1_AssistResponse>,
            DispatchQueue,
            AssistState,
            @escaping (Result<String, Error>) -> Void
        ) -> Void
    ) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
            let channel = ClientConnection.usingPlatformAppropriateTLS(for: group).connect(host: host, port: port)
            var client = Suki_Pb_SukiServer_V1_AssistantNIOClient(channel: channel)
            applyMetadata(to: &client, credentials: credentials)

            let requestQueue = DispatchQueue(label: "com.suki.watch.grpc.assist")
            let state = AssistState()
            var finished = false
            var timeoutWorkItem: DispatchWorkItem?

            let finish: (Result<String, Error>) -> Void = { result in
                requestQueue.async {
                    guard !finished else { return }
                    finished = true
                    timeoutWorkItem?.cancel()
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    _ = channel.close()
                    try? group.syncShutdownGracefully()
                }
            }

            var stream: BidirectionalStreamingCall<
                Suki_Pb_SukiServer_V1_AssistRequest,
                Suki_Pb_SukiServer_V1_AssistResponse
            >!
            stream = client.assist { response in
                guard case .legacyResponse(let dialog)? = response.response else { return }
                onLegacyResponse(dialog, stream, requestQueue, state, finish)
            }

            stream.status.whenComplete { result in
                requestQueue.async {
                    guard !finished else { return }
                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        finish(.failure(NoteSubmitError.streamFailed(error.localizedDescription)))
                    }
                }
            }

            let timeout = DispatchWorkItem {
                finish(.failure(NoteSubmitError.timedOut))
            }
            timeoutWorkItem = timeout
            requestQueue.asyncAfter(deadline: .now() + .seconds(Int(timeoutSeconds)), execute: timeout)

            requestQueue.asyncAfter(deadline: .now() + .milliseconds(250)) {
                onStreamReady(stream, requestQueue, finish)
            }
        }
    }

    private static func applyMetadata(
        to client: inout Suki_Pb_SukiServer_V1_AssistantNIOClient,
        credentials: NoteSubmitCredentials
    ) {
        client.defaultCallOptions.customMetadata.add(
            name: "suki_session_id",
            value: credentials.sessionId,
            indexing: .nonIndexable
        )
        client.defaultCallOptions.customMetadata.add(
            name: "suki_user_id",
            value: credentials.userId,
            indexing: .nonIndexable
        )
        client.defaultCallOptions.customMetadata.add(
            name: "suki_organization_id",
            value: credentials.organizationId,
            indexing: .nonIndexable
        )
        client.defaultCallOptions.customMetadata.add(name: "suki_user_agent", value: "watchOS-Suki", indexing: .nonIndexable)
        client.defaultCallOptions.customMetadata.add(name: "suki_user_role", value: "USER", indexing: .nonIndexable)
        client.defaultCallOptions.customMetadata.add(name: "jwt_token", value: credentials.jwtToken, indexing: .nonIndexable)
        client.defaultCallOptions.customMetadata.add(
            name: "suki_jwt_access_token",
            value: credentials.accessToken,
            indexing: .nonIndexable
        )
        client.defaultCallOptions.customMetadata.add(name: "is_emr", value: "true", indexing: .nonIndexable)
        client.defaultCallOptions.customMetadata.add(name: "suki_primary_emr", value: "UNKNOWN_EMR", indexing: .nonIndexable)
        client.defaultCallOptions.customMetadata.add(name: "suki_secondary_emr", value: "ATHENA_EMR", indexing: .nonIndexable)
        client.defaultCallOptions.customMetadata.add(
            name: "suki_request_id",
            value: UUID().uuidString,
            indexing: .nonIndexable
        )
    }
}
