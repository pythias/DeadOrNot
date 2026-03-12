import Foundation
import UserNotifications
import UIKit

final class NotificationManager: NSObject {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private(set) var deviceToken: String = ""

    private override init() {
        super.init()
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let err = error {
                print("通知权限请求出错：", err)
            } else {
                print("通知权限：", granted)
                if granted {
                    self.registerForRemoteNotifications()
                }
            }
        }
    }

    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // 注册 APNs 设备令牌成功后的回调
    func didRegisterForRemoteNotificationsWithDeviceToken(_ token: Data) {
        let tokenParts = token.map { data in String(format: "%02.2hhx", data) }
        let tokenString = tokenParts.joined()
        self.deviceToken = tokenString
        print("APNs Token: \(tokenString)")

        // 保存到 UserDefaults
        UserDefaults.standard.set(tokenString, forKey: "DeadOrNot.apnsToken")

        // 通知 UserInfo 更新
        NotificationCenter.default.post(name: .apnsTokenUpdated, object: nil, userInfo: ["token": tokenString])
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        print("APNs 注册失败: \(error.localizedDescription)")
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

// 扩展 Notification.Name
extension Notification.Name {
    static let apnsTokenUpdated = Notification.Name("apnsTokenUpdated")
}
