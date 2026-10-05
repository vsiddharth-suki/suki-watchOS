import UserNotifications
import WatchKit

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    private let recordingPauseNotificationDelegate = RecordingPauseNotificationDelegate()

    func applicationDidFinishLaunching() {
        let center = UNUserNotificationCenter.current()
        center.delegate = recordingPauseNotificationDelegate
        Task { await RecordingPauseNotificationService.ensureAuthorization() }
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let urlSessionTask = task as? WKURLSessionRefreshBackgroundTask {
                AmbientBackgroundUploadSession.shared.prepareForBackgroundEvents {
                    urlSessionTask.setTaskCompletedWithSnapshot(false)
                }
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
