import Foundation

/// Keeps ambient metadata + audio upload alive after the user leaves the ambient flow UI.
@MainActor
final class AmbientSessionCompletion {
    static let shared = AmbientSessionCompletion()

    private var retainedService: AmbientService?
    private(set) var isRunning = false
    /// Existing notes whose ambient audio is still uploading or whose generation has not been confirmed finished.
    private var expectingGenerationNoteIds: Set<String> = []
    private var uploadingNoteIds: Set<String> = []
    /// Bumped when an upload finishes so an in-flight status fetch can ignore a stale "not generating" result.
    private var uploadEpochByNoteId: [String: Int] = [:]
    private var expectationStartedAt: [String: Date] = [:]

    func expectsGeneration(anyOf noteIds: [String]) -> Bool {
        noteIds.contains { expectingGenerationNoteIds.contains($0) }
    }

    func isUploading(anyOf noteIds: [String]) -> Bool {
        noteIds.contains { uploadingNoteIds.contains($0) }
    }

    func uploadEpoch(for noteIds: [String]) -> Int {
        noteIds.map { uploadEpochByNoteId[$0] ?? 0 }.max() ?? 0
    }

    /// How long this note has been waiting on ambient generation. `nil` when it is not expected.
    func expectationAge(for noteIds: [String]) -> TimeInterval? {
        let starts = noteIds.compactMap { expectationStartedAt[$0] }
        guard let started = starts.min() else { return nil }
        return Date().timeIntervalSince(started)
    }

    func clearExpectation(noteIds: [String]) {
        for noteId in noteIds {
            expectingGenerationNoteIds.remove(noteId)
            uploadingNoteIds.remove(noteId)
            expectationStartedAt.removeValue(forKey: noteId)
        }
    }

    /// Runs finish work on a detached task so navigation does not cancel the upload.
    func start(
        service: AmbientService,
        noteId: String?,
        operation: @escaping @MainActor () async throws -> Void,
        onComplete: @escaping @MainActor (Result<Void, Error>) -> Void
    ) {
        isRunning = true
        retainedService = service
        if let noteId, !noteId.isEmpty {
            expectingGenerationNoteIds.insert(noteId)
            uploadingNoteIds.insert(noteId)
            if expectationStartedAt[noteId] == nil {
                expectationStartedAt[noteId] = Date()
            }
        }
        Task.detached { @MainActor in
            defer {
                self.retainedService = nil
                self.isRunning = false
                if let noteId, !noteId.isEmpty {
                    self.uploadingNoteIds.remove(noteId)
                    self.uploadEpochByNoteId[noteId, default: 0] += 1
                }
            }
            do {
                try await operation()
                onComplete(.success(()))
            } catch {
                if let noteId, !noteId.isEmpty {
                    self.expectingGenerationNoteIds.remove(noteId)
                    self.expectationStartedAt.removeValue(forKey: noteId)
                }
                onComplete(.failure(error))
            }
        }
    }
}
