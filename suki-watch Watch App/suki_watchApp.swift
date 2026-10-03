import SwiftUI

@main
struct suki_watch_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    init() {
        AmbientBackgroundUploadSession.shared.prepareForBackgroundEvents()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
