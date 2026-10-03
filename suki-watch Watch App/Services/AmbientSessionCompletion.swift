import Foundation

/// Keeps ambient metadata + audio upload alive after the user leaves the ambient flow UI.
@MainActor
final class AmbientSessionCompletion {
    static let shared = AmbientSessionCompletion()

    private var retainedService: AmbientService?
    private(set) var isRunning = false

    /// Runs finish work on a detached task so navigation does not cancel the upload.
    func start(
        service: AmbientService,
        operation: @escaping @MainActor () async throws -> Void,
        onComplete: @escaping @MainActor (Result<Void, Error>) -> Void
    ) {
        isRunning = true
        retainedService = service
        Task.detached { @MainActor in
            defer {
                self.retainedService = nil
                self.isRunning = false
            }
            do {
                try await operation()
                onComplete(.success(()))
            } catch {
                onComplete(.failure(error))
            }
        }
    }
}
