import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: CheckInStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var primaryGreen: Color {
        Color(red: 0.2, green: 0.7, blue: 0.3)
    }

    // 按月份分组的打卡记录
    private var groupedDates: [(String, [String])] {
        // 使用 historyDatetimes 来获取完整的打卡时间
        guard !store.historyDatetimes.isEmpty else {
            // 如果没有服务器数据，使用本地日期
            return groupLocalDates(store.dates.sorted().reversed())
        }

        // 按日期分组
        var grouped: [String: [String]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy年MM月"

        for datetimeStr in store.historyDatetimes.sorted().reversed() {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var date = formatter.date(from: datetimeStr)

            if date == nil {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: datetimeStr)
            }

            guard let date = date else { continue }

            let dateStr = dateFormatter.string(from: date)
            let monthKey = monthFormatter.string(from: date)

            if grouped[monthKey] == nil {
                grouped[monthKey] = []
            }
            grouped[monthKey]?.append(dateStr)
        }

        return grouped.sorted { $0.key > $1.key }
    }

    private func groupLocalDates(_ dates: [String]) -> [(String, [String])] {
        var grouped: [String: [String]] = [:]
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy年MM月"

        for dateStr in dates {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: dateStr) else { continue }

            let monthKey = monthFormatter.string(from: date)
            if grouped[monthKey] == nil {
                grouped[monthKey] = []
            }
            grouped[monthKey]?.append(dateStr)
        }

        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        List {
            if store.dates.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("暂无打卡记录")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("完成首次打卡后，记录将显示在这里")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .listRowBackground(Color.clear)
            } else {
                ForEach(groupedDates, id: \.0) { month, dates in
                    Section(header: Text(month)) {
                        ForEach(dates, id: \.self) { dateStr in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(primaryGreen)

                                Text(formatDate(dateStr))
                                    .font(.body)

                                Spacer()

                                if let time = getTimeForDate(dateStr) {
                                    Text(time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("打卡历史")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: dateStr) else { return dateStr }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            let weekday = weekdayFormatter.string(from: date)
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MM月dd日"
            return displayFormatter.string(from: date) + " " + weekday
        }
    }

    private func getTimeForDate(_ dateStr: String) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        guard let targetDate = dateFormatter.date(from: dateStr) else { return nil }

        for datetimeStr in store.historyDatetimes {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var date = formatter.date(from: datetimeStr)

            if date == nil {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: datetimeStr)
            }

            guard let date = date else { continue }

            let calendar = Calendar.current
            if calendar.isDate(date, inSameDayAs: targetDate) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                return timeFormatter.string(from: date)
            }
        }

        return nil
    }
}
