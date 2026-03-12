import SwiftUI
import UIKit

@main
struct DeadOrNotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = CheckInStore()
    @StateObject private var userInfo = UserInfo()
    private let notificationManager = NotificationManager.shared

    init() {
        // 尽早请求通知权限（你也可以在用户第一次操作时请求）
        notificationManager.requestAuthorization()

        // 启动时自动登录
        Task {
            do {
                try await APIService.shared.login()
            } catch {
                print("Auto login failed: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if userInfo.isSetupComplete() {
                ContentView()
                    .environmentObject(store)
                    .environmentObject(userInfo)
                    .onAppear {
                        store.reloadFromStorage()
                        // 启动时根据已有打卡数据安排/校正提醒
                        store.scheduleMissedReminderIfNeeded()
                    }
            } else {
                NavigationStack {
                    SetupView(userInfo: userInfo, isSetupComplete: .constant(false), isStandalone: true)
                }
                .onAppear {
                    store.reloadFromStorage()
                }
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationManager.shared.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationManager.shared.didFailToRegisterForRemoteNotificationsWithError(error)
    }
}
