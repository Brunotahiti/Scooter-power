import UserNotifications

/// Notifications locales (rappels d'entretien, badges, bilan de la semaine).
/// Rien ne quitte l'iPhone.
enum LocalNotifier {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}

/// Affiche aussi les notifications quand l'app est ouverte (badge gagné à l'arrivée).
final class ForegroundNotifications: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = ForegroundNotifications()

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
