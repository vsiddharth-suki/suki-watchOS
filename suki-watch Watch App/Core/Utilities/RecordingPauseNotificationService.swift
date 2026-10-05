import Foundation
import UserNotifications

enum RecordingPauseNotificationService {
    static let requestIdentifierPrefix = "ambient.recording.paused"

    static func ensureAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            print("[RecordingPauseNotification] authorization error: \(error.localizedDescription)")
        }
    }

    /// Shown when recording pauses because the watch locked or left the foreground.
    static func notifyRecordingPaused() async {
        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                print("[RecordingPauseNotification] authorization error: \(error.localizedDescription)")
            }
            settings = await center.notificationSettings()
        }

        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            print("[RecordingPauseNotification] skipped — status \(settings.authorizationStatus.rawValue)")
            return
        }

        // Give scene transition time to finish so the system will surface the alert.
        try? await Task.sleep(nanoseconds: 750_000_000)

        let content = UNMutableNotificationContent()
        content.title = "Recording paused"
        content.body = "Open Suki to resume ambient recording."
        content.sound = nil

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "\(requestIdentifierPrefix).\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            center.add(request) { error in
                if let error {
                    print("[RecordingPauseNotification] add failed: \(error.localizedDescription)")
                } else {
                    print("[RecordingPauseNotification] scheduled \(identifier)")
                }
                continuation.resume()
            }
        }
    }

    static func clearRecordingPausedNotification() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(requestIdentifierPrefix) }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
        center.getDeliveredNotifications { notifications in
            let ids = notifications.map(\.request.identifier).filter { $0.hasPrefix(requestIdentifierPrefix) }
            guard !ids.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }
}
