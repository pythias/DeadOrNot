import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let err = error {
                print("通知权限请求出错：", err)
            } else {
                print("通知权限：", granted)
            }
        }
    }

    func scheduleCalendarNotification(identifier: String, title: String, body: String, dateComponents: DateComponents, repeats: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let err = error { print("安排通知出错：", err) }
            else { print("已安排通知：", identifier, dateComponents) }
        }
    }

    func scheduleImmediateNotification(identifier: String, title: String, body: String, afterSeconds: TimeInterval = 5) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, afterSeconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let err = error { print("安排即时通知出错：", err) }
            else { print("已安排即时通知：", identifier) }
        }
    }

    func removePendingNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("取消通知：", identifier)
    }
}
