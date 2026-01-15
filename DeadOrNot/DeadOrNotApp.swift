import SwiftUI

@main
struct DeadOrNotApp: App {
    @StateObject private var store = CheckInStore()
    @StateObject private var userInfo = UserInfo()
    private let notificationManager = NotificationManager.shared

    init() {
        // 尽早请求通知权限（你也可以在用户第一次操作时请求）
        notificationManager.requestAuthorization()
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
