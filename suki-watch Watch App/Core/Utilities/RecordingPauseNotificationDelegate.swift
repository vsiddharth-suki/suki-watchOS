import Foundation
import UserNotifications

/// Presents local notifications while the app is still active or inactive (e.g. during lock transition).
final class RecordingPauseNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard notification.request.identifier.hasPrefix(RecordingPauseNotificationService.requestIdentifierPrefix) else {
            return []
        }
        return [.banner, .list, .sound]
    }
}
