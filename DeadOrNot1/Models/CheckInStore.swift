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
