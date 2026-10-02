import AVFoundation
import Foundation

@MainActor
final class AmbientService: NSObject {
    private let api: APIClient
    private let sessionStore: SessionStore
    private var recorder: AVAudioRecorder?
    private(set) var sessionId: String = ""
    private(set) var recordingURL: URL?
    private(set) var isPaused = false

    init(api: APIClient = APIClient(), sessionStore: SessionStore = .shared) {
        self.api = api
        self.sessionStore = sessionStore
    }

    func beginSession() throws {
        sessionId = UUID().uuidString.lowercased()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(sessionId).wav")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)

        recorder = try AVAudioRecorder(url: url, settings: settings)
        isPaused = false
        recorder?.record()
    }

    func pauseRecording() {
        guard recorder?.isRecording == true else { return }
        recorder?.pause()
        isPaused = true
    }

    func resumeRecording() {
        guard isPaused else { return }
        recorder?.record()
        isPaused = false
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        isPaused = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func submitMetadata(
        noteTypeId: String?,
        noteId: String?,
        patientId: String?,
        appointmentId: String?,
        autoSubmitToEMR: Bool = false
    ) async throws {
        let body = AmbientSessionMetadataBody(
            flowContext: AmbientFlowContext(
                noteTypeId: noteTypeId,
                noteId: noteId,
                visitTypeId: nil
            ),
            sessionContext: AmbientSessionContext(
                offline: true,
                autoSubmitToEMR: autoSubmitToEMR,
                deviceInfo: "suki-watch-hackathon",
                onDeviceTranscription: true
            ),
            patientContext: AmbientPatientContext(patientId: patientId),
            appointmentContext: AmbientAppointmentContext(appointmentId: appointmentId),
            compositionContext: nil
        )
        let data = try JSONEncoder().encode(body)
        let descriptor = APIRequestDescriptor(
            host: .gateway,
            path: "/v1/ambient/session/\(sessionId)/metadata",
            method: "POST",
            body: data
        )
        let response = try await api.send(descriptor, as: AmbientSessionMetadataResponse.self)
        guard response.ambientSessionId != nil else {
            throw APIError.server(response.code ?? -1, response.message ?? "Ambient metadata failed")
        }
    }

    func uploadRecordingIfNeeded() async throws {
        guard let fileURL = recordingURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let userId = sessionStore.userId, let orgId = sessionStore.organizationId else { return }

        let uploadBody = FetchUploadURLBody(
            userId: userId,
            scope: UploadScope(organizationId: orgId),
            metadata: UploadMetadata(payattentionSessionIdentifier: sessionId)
        )
        let bodyData = try JSONEncoder().encode(uploadBody)
        let descriptor = APIRequestDescriptor(
            host: .gateway,
            path: "/payattention/generate-presigned-url",
            method: "POST",
            body: bodyData
        )
        let uploadInfo = try await api.send(descriptor, as: FetchUploadURLResponse.self)
        guard let uploadURL = URL(string: uploadInfo.url) else { return }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("audio/wave", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: request, fromFile: fileURL)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw APIError.server((response as? HTTPURLResponse)?.statusCode ?? -1, "Audio upload failed")
        }
    }
}
