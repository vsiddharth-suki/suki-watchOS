import Foundation

/// Background `URLSession` upload for ambient WAV files (survives app suspend / watch lock).
final class AmbientBackgroundUploadSession: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = AmbientBackgroundUploadSession()

    static let sessionIdentifier = "com.suki.watch.ambient.audio.upload"

    private let lock = NSLock()
    private var urlSession: URLSession!
    private var taskCompletions: [Int: (Result<Void, Error>) -> Void] = [:]
    private var backgroundEventsCompletion: (() -> Void)?

    private override init() {
        super.init()
        urlSession = makeSession()
    }

    /// Re-attach delegate after launch or when handling `WKURLSessionRefreshBackgroundTask`.
    func prepareForBackgroundEvents(completion: (() -> Void)? = nil) {
        lock.lock()
        backgroundEventsCompletion = completion
        lock.unlock()
        urlSession = makeSession()
        print("[AmbientUpload] Prepared background URL session")
    }

    func upload(fileURL: URL, to uploadURL: URL, ambientSessionId: String) async throws {
        await AmbientExtendedRuntimeKeeper.shared.begin()
        defer {
            Task { @MainActor in
                AmbientExtendedRuntimeKeeper.shared.end()
            }
        }
        AmbientUploadPendingStore.save(fileURL: fileURL, ambientSessionId: ambientSessionId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "PUT"
            request.setValue("audio/wave", forHTTPHeaderField: "Content-Type")

            let task = urlSession.uploadTask(with: request, fromFile: fileURL)
            storeCompletion(for: task.taskIdentifier) { result in
                continuation.resume(with: result.map { _ in () })
            }
            print("[AmbientUpload] Started background upload task \(task.taskIdentifier) for session \(ambientSessionId)")
            task.resume()
        }

        AmbientUploadPendingStore.removePendingFileIfPresent()
    }

    // MARK: - URLSessionDelegate

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        lock.lock()
        let completion = backgroundEventsCompletion
        backgroundEventsCompletion = nil
        lock.unlock()
        DispatchQueue.main.async {
            completion?()
        }
    }

    // MARK: - URLSessionTaskDelegate

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let result: Result<Void, Error>
        if let error {
            result = .failure(error)
        } else if let http = task.response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            result = .failure(APIError.server(http.statusCode, "Audio upload failed"))
        } else {
            result = .success(())
        }

        if case .success = result {
            print("[AmbientUpload] Upload task \(task.taskIdentifier) completed successfully")
        } else if case .failure(let failure) = result {
            print("[AmbientUpload] Upload task \(task.taskIdentifier) failed: \(failure.localizedDescription)")
        }

        let waiter = takeCompletion(for: task.taskIdentifier)
        if let waiter {
            waiter(result)
        } else if case .success = result {
            AmbientUploadPendingStore.removePendingFileIfPresent()
            Task { @MainActor in
                AmbientExtendedRuntimeKeeper.shared.end()
            }
        } else {
            AmbientUploadPendingStore.clear()
            Task { @MainActor in
                AmbientExtendedRuntimeKeeper.shared.end()
            }
        }
    }

    // MARK: - Private

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    private func storeCompletion(for taskId: Int, handler: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        taskCompletions[taskId] = handler
        lock.unlock()
    }

    private func takeCompletion(for taskId: Int) -> ((Result<Void, Error>) -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        return taskCompletions.removeValue(forKey: taskId)
    }
}
