import Foundation

/// Tracks in-flight background audio upload so completion after app relaunch can remove the WAV.
enum AmbientUploadPendingStore {
    private static let relativePathKey = "ambient.upload.pending.relativeFilePath"
    private static let sessionIdKey = "ambient.upload.pending.sessionId"
    private static let legacyAbsolutePathKey = "ambient.upload.pending.filePath"

    private static let recordingsFolderName = "AmbientRecordings"

    struct Pending: Equatable {
        var relativePath: String
        var ambientSessionId: String

        var fileURL: URL {
            AmbientUploadPendingStore.fileURL(relativePath: relativePath)
        }
    }

    /// Application Support — stable across launches; absolute container path changes each install/relaunch.
    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    static func ensureRecordingsDirectory() throws -> URL {
        let directory = applicationSupportDirectory
            .appendingPathComponent(recordingsFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func recordingFileURL(ambientSessionId: String) throws -> URL {
        try ensureRecordingsDirectory()
            .appendingPathComponent("\(ambientSessionId).wav", isDirectory: false)
    }

    static func relativePath(for fileURL: URL) throws -> String {
        let root = applicationSupportDirectory.standardizedFileURL.path
        let file = fileURL.standardizedFileURL.path
        let prefix = root + "/"
        guard file.hasPrefix(prefix) else {
            throw AmbientUploadStoreError.fileOutsideApplicationSupport(fileURL)
        }
        return String(file.dropFirst(prefix.count))
    }

    static func fileURL(relativePath: String) -> URL {
        applicationSupportDirectory.appendingPathComponent(relativePath, isDirectory: false)
    }

    static func save(fileURL: URL, ambientSessionId: String) {
        guard let relative = try? relativePath(for: fileURL) else {
            print("[AmbientUpload] Refusing to persist non–Application Support path: \(fileURL.path)")
            return
        }
        UserDefaults.standard.set(relative, forKey: relativePathKey)
        UserDefaults.standard.set(ambientSessionId, forKey: sessionIdKey)
        UserDefaults.standard.removeObject(forKey: legacyAbsolutePathKey)
    }

    static func load() -> Pending? {
        if let relative = UserDefaults.standard.string(forKey: relativePathKey),
           let sessionId = UserDefaults.standard.string(forKey: sessionIdKey),
           !relative.isEmpty, !sessionId.isEmpty {
            return Pending(relativePath: relative, ambientSessionId: sessionId)
        }

        if let legacyAbsolute = UserDefaults.standard.string(forKey: legacyAbsolutePathKey),
           let sessionId = UserDefaults.standard.string(forKey: sessionIdKey),
           !legacyAbsolute.isEmpty, !sessionId.isEmpty {
            let fileName = URL(fileURLWithPath: legacyAbsolute).lastPathComponent
            let relative = "\(recordingsFolderName)/\(fileName)"
            UserDefaults.standard.set(relative, forKey: relativePathKey)
            UserDefaults.standard.removeObject(forKey: legacyAbsolutePathKey)
            return Pending(relativePath: relative, ambientSessionId: sessionId)
        }

        return nil
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: relativePathKey)
        UserDefaults.standard.removeObject(forKey: sessionIdKey)
        UserDefaults.standard.removeObject(forKey: legacyAbsolutePathKey)
    }

    static func removePendingFileIfPresent() {
        guard let pending = load() else { return }
        let url = pending.fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
            print("[AmbientUpload] Deleted recording after background upload: \(url.path)")
        }
        clear()
    }
}

enum AmbientUploadStoreError: Error {
    case fileOutsideApplicationSupport(URL)
}
