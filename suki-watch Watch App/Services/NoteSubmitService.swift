import Foundation
import SukiGRPC

final class NoteSubmitService {
    private func credentials(from session: SessionStore) throws -> NoteSubmitCredentials {
        guard
            let jwt = session.grpcJWTToken,
            let access = session.accessToken,
            let userId = session.userId,
            let organizationId = session.organizationId
        else {
            throw NoteSubmitError.missingCredentials
        }
        return NoteSubmitCredentials(
            jwtToken: jwt,
            accessToken: access,
            userId: userId,
            organizationId: organizationId,
            sessionId: session.sessionId
        )
    }

    func persistSectionEdits(payload: NoteSubmitPayload, session: SessionStore) async throws {
        let credentials = try credentials(from: session)
        try await NoteSubmitGRPCClient.persistSectionEdits(
            payload: payload,
            credentials: credentials,
            host: GRPCConfiguration.host,
            port: GRPCConfiguration.port
        )
    }

    func submit(payload: NoteSubmitPayload, session: SessionStore) async throws {
        let credentials = try credentials(from: session)
        _ = try await NoteSubmitGRPCClient.submit(
            payload: payload,
            credentials: credentials,
            host: GRPCConfiguration.host,
            port: GRPCConfiguration.port
        )
    }

    func createNote(
        noteTypeId: String,
        patientId: String,
        appointmentId: String?,
        session: SessionStore
    ) async throws -> String {
        let credentials = try credentials(from: session)
        return try await NoteSubmitGRPCClient.createNote(
            payload: NoteCreatePayload(
                noteTypeId: noteTypeId,
                patientId: patientId,
                appointmentId: appointmentId ?? ""
            ),
            credentials: credentials,
            host: GRPCConfiguration.host,
            port: GRPCConfiguration.port
        )
    }
}
