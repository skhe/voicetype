import UserNotifications

enum NotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func show(text: String) {
        let content = UNMutableNotificationContent()
        content.title = "VoiceType"
        let preview = text.count > 80 ? String(text.prefix(80)) + "…" : text
        content.body = preview
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
