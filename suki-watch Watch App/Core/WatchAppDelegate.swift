import WatchKit

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
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
