import XCTest
@testable import suki_watch_Watch_App

@MainActor
final class AmbientSessionGeneratingTests: XCTestCase {
    func testAmbientNoteSessionDecodesAmbientStatus() throws {
        let json = """
        {
          "note_id": "note-1",
          "ambient_session_id": "session-1",
          "ambient_status": "IN_PROGRESS",
          "transcript_status": "UNAVAILABLE"
        }
        """.data(using: .utf8)!

        let session = try JSONDecoder().decode(AmbientNoteSession.self, from: json)
        XCTAssertEqual(session.ambientStatus, .inProgress)
        XCTAssertEqual(session.transcriptStatus, .unavailable)
    }

    func testUnknownAmbientStatusDecodesAsNil() throws {
        let json = """
        {
          "note_id": "note-1",
          "ambient_status": "SOME_FUTURE_STATUS"
        }
        """.data(using: .utf8)!

        let session = try JSONDecoder().decode(AmbientNoteSession.self, from: json)
        XCTAssertNil(session.ambientStatus)
    }

    func testHasAmbientSessionInProgress() throws {
        let inProgress = try decodeSession(status: "IN_PROGRESS")
        let collecting = try decodeSession(status: "COLLECTING_AUDIO")
        let success = try decodeSession(status: "SUCCESS")

        XCTAssertTrue([inProgress].hasAmbientSessionInProgress)
        XCTAssertTrue([collecting, success].hasAmbientSessionInProgress)
        XCTAssertFalse([success].hasAmbientSessionInProgress)
        XCTAssertFalse([AmbientNoteSession]().hasAmbientSessionInProgress)
    }

    func testGeneratingTextThresholds() {
        let viewModel = NoteViewModel(noteId: "note-1", patientId: nil, patientName: nil)
        XCTAssertEqual(viewModel.generatingText, "Uploading")

        viewModel.generatingProgress = 0.19
        XCTAssertEqual(viewModel.generatingText, "Uploading")

        viewModel.generatingProgress = 0.20
        XCTAssertEqual(viewModel.generatingText, "Processing")

        viewModel.generatingProgress = 0.40
        XCTAssertEqual(viewModel.generatingText, "Generating")
    }

    private func decodeSession(status: String) throws -> AmbientNoteSession {
        let json = """
        { "ambient_status": "\(status)" }
        """.data(using: .utf8)!
        return try JSONDecoder().decode(AmbientNoteSession.self, from: json)
    }
}
