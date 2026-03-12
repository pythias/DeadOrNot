import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: CheckInStore
    @EnvironmentObject var userInfo: UserInfo
    @Environment(\.colorScheme) var colorScheme
    @State private var showSetup = false
    @State private var showSuccessAnimation = false
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    @State private var showHistory = false

    private var primaryGreen: Color {
        Color(red: 0.2, green: 0.7, blue: 0.3)
    }

    // 根据暗黑模式调整背景色
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(UIColor.systemBackground)
    }

    // 根据暗黑模式调整次要背景色
    private var secondaryBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.secondary.opacity(0.1)
    }

    // 已打卡状态的灰色
    private var checkedInGray: Color {
        colorScheme == .dark ? Color.gray : Color.secondary
    }

    // 已打卡状态的光晕颜色
    private func checkedInGlowOpacity(_ opacity: Double) -> Color {
        colorScheme == .dark ? Color.white.opacity(opacity) : Color.secondary.opacity(opacity)
    }

    // 从服务器统计中获取连续天数，如果没有则使用本地计算
    private var currentStreak: Int {
        store.stats?.currentStreak ?? store.currentStreak()
    }

    // 从服务器统计中获取总天数，如果没有则使用本地计算
    private var totalDays: Int {
        store.stats?.totalDays ?? dates.count
    }

    // 从服务器统计中获取最后打卡时间
    private var lastCheckinDateTime: String? {
        store.stats?.lastCheckinDateTime
    }

    // 本地日期集合
    private var dates: Set<String> {
        store.dates
    }

    var body: some View {
        NavigationStack {
            mainView
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showSetup = true
                        }) {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
        }
        .sheet(isPresented: $showSetup) {
            NavigationStack {
                SetupView(userInfo: userInfo, isSetupComplete: $showSetup)
            }
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                HistoryView(store: store)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完成") {
                                showHistory = false
                            }
                        }
                    }
            }
        }
    }
    
    private var mainView: some View {
        ScrollView {
            VStack(spacing: 24) {
                        // 大圆形按钮或已签到状态
                        if store.isCheckedInToday() {
                            // 已签到状态
                            ZStack {
                                // 外圈光晕效果
                                Circle()
                                    .fill(checkedInGlowOpacity(0.15))
                                    .frame(width: 300, height: 300)

                                Circle()
                                    .fill(checkedInGlowOpacity(0.25))
                                    .frame(width: 260, height: 260)

                                Circle()
                                    .fill(checkedInGlowOpacity(0.35))
                                    .frame(width: 220, height: 220)

                                // 主按钮
                                Circle()
                                    .fill(checkedInGray)
                                    .frame(width: 180, height: 180)

                                VStack(spacing: 12) {
                                    // 成功图标
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 50, height: 50)

                                        Image(systemName: "checkmark")
                                            .font(.system(size: 30, weight: .bold))
                                            .foregroundColor(checkedInGray)
                                    }

                                    Text("今日已签到")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.top, 24)
                            .padding(.bottom, 16)
                        } else {
                            // 签到按钮
                            Button(action: {
                                store.checkInToday()
                                withAnimation {
                                    showSuccessAnimation = true
                                }
                                // 2秒后恢复
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showSuccessAnimation = false
                                    }
                                }
                            }) {
                                ZStack {
                                    // 外圈光晕效果（多层同心圆，透明度递减）
                                    Circle()
                                        .fill(primaryGreen.opacity(0.15))
                                        .frame(width: 300, height: 300)
                                    
                                    Circle()
                                        .fill(primaryGreen.opacity(0.25))
                                        .frame(width: 260, height: 260)
                                    
                                    Circle()
                                        .fill(primaryGreen.opacity(0.35))
                                        .frame(width: 220, height: 220)
                                    
                                    // 主按钮
                                    Circle()
                                        .fill(primaryGreen)
                                        .frame(width: 180, height: 180)
                                    
                                    VStack(spacing: 12) {
                                        if showSuccessAnimation {
                                            // 成功图标
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white)
                                                    .frame(width: 50, height: 50)
                                                
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 30, weight: .bold))
                                                    .foregroundColor(primaryGreen)
                                            }
                                        } else {
                                            // 幽灵图标（白色轮廓，两个眼睛和一个嘴巴）
                                            ZStack {
                                                // 幽灵身体（上半部分圆形，下半部分波浪）
                                                ZStack {
                                                    // 上半部分圆形
                                                    Circle()
                                                        .trim(from: 0, to: 0.5)
                                                        .stroke(Color.white, lineWidth: 3)
                                                        .frame(width: 36, height: 36)
                                                        .rotationEffect(.degrees(180))
                                                        .offset(y: -9)
                                                    
                                                    // 下半部分波浪（简化版）
                                                    VStack(spacing: 0) {
                                                        HStack(spacing: 6) {
                                                            Circle()
                                                                .trim(from: 0, to: 0.5)
                                                                .stroke(Color.white, lineWidth: 3)
                                                                .frame(width: 12, height: 12)
                                                                .rotationEffect(.degrees(180))
                                                            
                                                            Circle()
                                                                .trim(from: 0, to: 0.5)
                                                                .stroke(Color.white, lineWidth: 3)
                                                                .frame(width: 12, height: 12)
                                                                .rotationEffect(.degrees(180))
                                                            
                                                            Circle()
                                                                .trim(from: 0, to: 0.5)
                                                                .stroke(Color.white, lineWidth: 3)
                                                                .frame(width: 12, height: 12)
                                                                .rotationEffect(.degrees(180))
                                                        }
                                                        .offset(y: 9)
                                                    }
                                                }
                                                .frame(width: 50, height: 50)
                                                
                                                // 两个眼睛
                                                HStack(spacing: 10) {
                                                    Circle()
                                                        .fill(Color.white)
                                                        .frame(width: 6, height: 6)
                                                    
                                                    Circle()
                                                        .fill(Color.white)
                                                        .frame(width: 6, height: 6)
                                                }
                                                .offset(y: -8)
                                                
                                                // 嘴巴（弧形）
                                                Ellipse()
                                                    .trim(from: 0, to: 0.5)
                                                    .stroke(Color.white, lineWidth: 2.5)
                                                    .frame(width: 16, height: 10)
                                                    .offset(y: 8)
                                            }
                                            .frame(width: 50, height: 50)
                                        }
                                        
                                        Text(showSuccessAnimation ? "签到成功" : "今日签到")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 24)
                            .padding(.bottom, 16)
                        }

                        // 打卡统计卡片
                        HStack(spacing: 16) {
                            // 连续打卡天数
                            StatCard(
                                title: "连续打卡",
                                value: "\(currentStreak)",
                                unit: "天",
                                icon: "flame.fill",
                                iconColor: .orange
                            )

                            // 总打卡天数
                            StatCard(
                                title: "总打卡",
                                value: "\(totalDays)",
                                unit: "天",
                                icon: "calendar",
                                iconColor: primaryGreen
                            )

                            // 最后打卡时间
                            StatCard(
                                title: "最后打卡",
                                value: lastCheckinDateTime != nil ? formatLastCheckin(lastCheckinDateTime!) : "暂无",
                                unit: "",
                                icon: "clock.fill",
                                iconColor: .blue
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // 查看历史按钮
                        Button(action: {
                            showHistory = true
                        }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("查看打卡历史")
                            }
                            .font(.subheadline)
                            .foregroundColor(primaryGreen)
                        }
                        .padding(.top, 8)

                        // 提示信息
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(primaryGreen)
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("多日未签到提醒")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("系统将以你的名义，在次日邮件通知你的紧急联系人")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(secondaryBackgroundColor)
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        // 协议链接
                        HStack(spacing: 4) {
                            Text("签到即同意")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                showTermsOfService = true
                            }) {
                                Text("用户协议")
                                    .font(.caption)
                                    .foregroundColor(primaryGreen)
                            }
                            
                            Text("和")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                showPrivacyPolicy = true
                            }) {
                                Text("隐私政策")
                                    .font(.caption)
                                    .foregroundColor(primaryGreen)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }

    }

    // 格式化最后打卡时间
    private func formatLastCheckin(_ datetime: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = formatter.date(from: datetime)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: datetime)
        }

        guard let date = date else { return "暂无" }

        let now = Date()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return "今天 " + timeFormatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return "昨天 " + timeFormatter.string(from: date)
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "MM/dd"
            return dayFormatter.string(from: date)
        }
    }
}

// 统计卡片组件
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            if !unit.isEmpty {
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}