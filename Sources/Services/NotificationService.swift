import UserNotifications

/// Wraps UNUserNotificationCenter: permission request and the 30-second pre-break heads-up.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() {
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Reports whether banners are allowed; when denied the app silently falls back to the overlay only.
    func isAuthorized(_ completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            let ok = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            DispatchQueue.main.async { completion(ok) }
        }
    }

    func postPreBreak(kind: BreakKind) {
        let content = UNMutableNotificationContent()
        content.title = "\(kind.title) in 30 seconds"
        content.body = "Wrap up what you're doing — time to rest your eyes soon."
        let request = UNNotificationRequest(identifier: "prebreak", content: content, trigger: nil)
        center.add(request) { _ in }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
