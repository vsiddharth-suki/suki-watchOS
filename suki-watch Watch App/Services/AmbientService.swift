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

    func beginSession() async throws {
        sessionId = UUID().uuidString.lowercased()
        let url = try AmbientUploadPendingStore.recordingFileURL(ambientSessionId: sessionId)
        recordingURL = url
        print("[Ambient] Recording saved to: \(url.path)")

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
        let activated = try await session.activate()
        guard activated else {
            throw AmbientAudioError.activationFailed
        }

        recorder = try AVAudioRecorder(url: url, settings: settings)
        isPaused = false
        recorder?.record()
    }

    func pauseRecording(playExitSound: Bool = true) {
        guard recorder?.isRecording == true else { return }
        recorder?.pause()
        isPaused = true
        if playExitSound {
            DictationSoundPlayer.playExitDictation()
        }
    }

    func resumeRecording() {
        guard isPaused else { return }
        recorder?.record()
        isPaused = false
    }

    func stopRecording() async {
        recorder?.stop()
        recorder = nil
        isPaused = false
        await deactivateAudioSession()
    }

    /// Prefer async `deactivate` when available; otherwise deactivate off the main thread
    /// so synchronous `setActive(false)` cannot hang the UI.
    private func deactivateAudioSession() async {
        if #available(watchOS 27.0, *) {
            do {
                _ = try await AVAudioSession.sharedInstance().deactivate()
            } catch {
                print("[Ambient] Failed to deactivate audio session: \(error.localizedDescription)")
            }
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
                } catch {
                    print("[Ambient] Failed to deactivate audio session: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
    }

    /// Stops recording and deletes the local WAV (user aborted the flow).
    func cancelSession() async {
        await stopRecording()
        discardRecordingFile()
    }

    private func discardRecordingFile() {
        guard let url = recordingURL else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
                print("[Ambient] Deleted recording file: \(url.path)")
            } catch {
                print("[Ambient] Failed to delete recording file: \(error.localizedDescription)")
            }
        }
        recordingURL = nil
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

        try await AmbientBackgroundUploadSession.shared.upload(
            fileURL: fileURL,
            to: uploadURL,
            ambientSessionId: sessionId
        )
        discardRecordingFile()
    }
}

private enum AmbientAudioError: LocalizedError {
    case activationFailed

    var errorDescription: String? {
        switch self {
        case .activationFailed:
            return "Failed to activate audio session"
        }
    }
}
