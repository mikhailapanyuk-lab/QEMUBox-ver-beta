import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        // Forward the background URLSession completion handler to the DownloadManager so it can call it when ready
        DownloadManager.shared.setBackgroundSessionCompletionHandler(completionHandler)
    }
}
