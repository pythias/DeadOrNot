import SwiftUI

@main
struct DeadOrNotApp: App {
    @StateObject private var store = CheckInStore()
    private let notificationManager = NotificationManager.shared

    init() {
        // 尽早请求通知权限（你也可以在用户第一次操作时请求）
        notificationManager.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    store.reloadFromStorage()
                    // 启动时根据已有打卡数据安排/校正提醒
                    store.scheduleMissedReminderIfNeeded()
                }
        }
    }
}
