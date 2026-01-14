#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="DeadOrNot"
ZIP_NAME="DeadOrNot.zip"

echo "Creating project structure in ./${ROOT_DIR} ..."

# Clean previous
rm -rf "${ROOT_DIR}" "${ZIP_NAME}"

mkdir -p "${ROOT_DIR}/Models"
mkdir -p "${ROOT_DIR}/Views"
mkdir -p "${ROOT_DIR}/Helpers"
mkdir -p "${ROOT_DIR}/Assets.xcassets/AppIcon.appiconset"

# DeadOrNotApp.swift
cat > "${ROOT_DIR}/DeadOrNotApp.swift" <<'EOF'
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
EOF

# Models/CheckInStore.swift
cat > "${ROOT_DIR}/Models/CheckInStore.swift" <<'EOF'
import Foundation
import Combine

final class CheckInStore: ObservableObject {
    @Published private(set) var dates: Set<String> = [] // yyyy-MM-dd
    private let userDefaultsKey = "DeadOrNot.checkinDates"
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()
    private let notificationManager = NotificationManager.shared
    private let missedNotificationIdentifier = "DeadOrNot_Missed3Days"

    init() {
        $dates
            .sink { [weak self] _ in self?.saveToStorage() }
            .store(in: &cancellables)
    }

    func reloadFromStorage() {
        if let arr = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
            dates = Set(arr)
        }
    }

    private func saveToStorage() {
        UserDefaults.standard.set(Array(dates), forKey: userDefaultsKey)
    }

    private func dateFormatter() -> DateFormatter {
        let df = DateFormatter()
        df.calendar = calendar
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }

    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    var todayString: String {
        dateFormatter().string(from: Date())
    }

    func isCheckedInToday() -> Bool {
        dates.contains(todayString)
    }

    func checkInToday() {
        let key = todayString
        dates.insert(key)
        // 每次打卡后取消旧提醒并重新安排
        cancelMissedReminder()
        scheduleMissedReminderIfNeeded()
    }

    func lastCheckinDate() -> Date? {
        let df = dateFormatter()
        let sorted = dates.compactMap { df.date(from: $0) }.sorted()
        return sorted.last
    }

    func currentStreak() -> Int {
        var streak = 0
        var day = startOfDay(Date())
        let df = dateFormatter()

        while true {
            let key = df.string(from: day)
            if dates.contains(key) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            } else { break }
        }
        return streak
    }

    func cancelMissedReminder() {
        notificationManager.removePendingNotification(identifier: missedNotificationIdentifier)
    }

    func scheduleMissedReminderIfNeeded(remindHour: Int = 9, minute: Int = 0) {
        guard let last = lastCheckinDate() else {
            // 从未打卡：从今天开始计时���可按需求改为不安排直到第一次打卡）
            let base = startOfDay(Date())
            scheduleReminder(baseDate: base, afterDays: 3, hour: remindHour, minute: minute)
            return
        }
        let base = startOfDay(last)
        scheduleReminder(baseDate: base, afterDays: 3, hour: remindHour, minute: minute)
    }

    private func scheduleReminder(baseDate: Date, afterDays: Int, hour: Int, minute: Int) {
        guard let triggerDate = calendar.date(byAdding: .day, value: afterDays, to: baseDate) else { return }
        var comps = calendar.dateComponents([.year, .month, .day], from: triggerDate)
        comps.hour = hour
        comps.minute = minute

        let now = Date()
        if let fire = calendar.date(from: comps), fire <= now {
            // 已过期 -> 立即安排短延迟通知
            notificationManager.scheduleImmediateNotification(
                identifier: missedNotificationIdentifier,
                title: "连续未打卡提醒",
                body: "你已连续 3 天未打卡，快打开“死了么”打个卡吧！"
            )
        } else {
            notificationManager.scheduleCalendarNotification(
                identifier: missedNotificationIdentifier,
                title: "连续未打卡提醒",
                body: "你已连续 3 天未打卡，快打开“死了么”打个卡吧！",
                dateComponents: comps
            )
        }
    }
}
EOF

# Helpers/NotificationManager.swift
cat > "${ROOT_DIR}/Helpers/NotificationManager.swift" <<'EOF'
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
EOF

# Views/ContentView.swift
cat > "${ROOT_DIR}/Views/ContentView.swift" <<'EOF'
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: CheckInStore

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("死了么")
                    .font(.largeTitle)
                    .bold()

                VStack {
                    Text("今日状态")
                    Text(store.isCheckedInToday() ? "已打卡 ✅" : "未打卡 ❌")
                        .font(.title2)
                        .foregroundColor(store.isCheckedInToday() ? .green : .red)
                }

                Button(action: {
                    store.checkInToday()
                }) {
                    Text(store.isCheckedInToday() ? "已打卡（已记录）" : "打卡")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(store.isCheckedInToday() ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(store.isCheckedInToday())

                HStack {
                    VStack(alignment: .leading) {
                        Text("当前连胜：")
                        Text("\(store.currentStreak()) 天").font(.title2).bold()
                    }
                    Spacer()
                }.padding()

                List {
                    Section(header: Text("打卡记录（最近）")) {
                        ForEach(store.dates.sorted(by: >), id: \.self) { d in
                            Text(d)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("首页")
        }
    }
}
EOF

# Info.plist
cat > "${ROOT_DIR}/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>com.yourname.DeadOrNot</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>DeadOrNot</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <false/>
        <key>UISceneConfigurations</key>
        <dict>
            <key>UIWindowSceneSessionRoleApplication</key>
            <array>
                <dict>
                    <key>UISceneConfigurationName</key>
                    <string>Default Configuration</string>
                    <key>UISceneDelegateClassName</key>
                    <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
                </dict>
            </array>
        </dict>
    </dict>
</dict>
</plist>
EOF

# README.md (Markdown file)
cat > "${ROOT_DIR}/README.md" <<'EOF'
# 死了么 (DeadOrNot)

简单的每日打卡 App 示例（SwiftUI + 本地通知）。当连续 3 天未打卡时发送本地提醒。

## 文件
- DeadOrNotApp.swift — App 入口
- Models/CheckInStore.swift — 打卡逻辑、数据持久化与提醒调度
- Helpers/NotificationManager.swift — 本地通知封装
- Views/ContentView.swift — 简单 UI
- Info.plist — 应用配置
- Assets.xcassets — 图标占位

## 快速运行
1. 用 Xcode 创建一个新的 App（SwiftUI）、或把本仓库放入 Xcode。
2. 运行到设备（推荐真机测试通知），首次启动会请求通知权限。
3. 点击“打卡”以记录今天；若连续 3 天未打卡，系统会发送本地通知。

## 打包为 zip
在项目父目录执行（macOS 终端）：