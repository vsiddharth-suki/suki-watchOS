import Foundation
import WatchKit

/// Keeps the app eligible to run while ambient audio uploads (e.g. wrist lowered).
@MainActor
final class AmbientExtendedRuntimeKeeper: NSObject, WKExtendedRuntimeSessionDelegate {
    static let shared = AmbientExtendedRuntimeKeeper()

    private var session: WKExtendedRuntimeSession?
    private(set) var isActive = false

    func begin() {
        guard session == nil else { return }
        let runtime = WKExtendedRuntimeSession()
        runtime.delegate = self
        session = runtime
        runtime.start()
        print("[AmbientUpload] Extended runtime session starting (requires WKBackgroundModes self-care + entitlement)")
    }

    func end() {
        guard let session else { return }
        session.invalidate()
        self.session = nil
        isActive = false
        print("[AmbientUpload] Extended runtime session ended")
    }

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("[AmbientUpload] Extended runtime session did start")
        Task { @MainActor in
            if self.session === extendedRuntimeSession {
                self.isActive = true
            }
        }
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("[AmbientUpload] Extended runtime session will expire")
    }

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        if let error {
            print("[AmbientUpload] Extended runtime invalidated: \(reason) \(error.localizedDescription)")
        } else {
            print("[AmbientUpload] Extended runtime invalidated: \(reason)")
        }
        Task { @MainActor in
            if self.session === extendedRuntimeSession {
                self.session = nil
                self.isActive = false
            }
        }
    }
}
