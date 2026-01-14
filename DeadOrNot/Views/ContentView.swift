import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: CheckInStore
    @EnvironmentObject var userInfo: UserInfo
    @Environment(\.colorScheme) var colorScheme
    @State private var showSetup = false
    @State private var showSuccessAnimation = false
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false

    var body: some View {
        ZStack {
            mainView
        }
        .sheet(isPresented: $showSetup) {
            SetupView(userInfo: userInfo, isSetupComplete: $showSetup)
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark 
            ? Color(red: 0.1, green: 0.15, blue: 0.1)
            : Color(red: 0.9, green: 0.95, blue: 0.9)
    }
    
    private var primaryGreen: Color {
        Color(red: 0.2, green: 0.7, blue: 0.3)
    }
    
    private var mainView: some View {
        ZStack {
            // 背景色，根据深色模式适配
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部设置按钮
                HStack {
                    Spacer()
                    Button(action: {
                        showSetup = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(primaryGreen)
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 60)
                    .padding(.bottom, 20)
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 大绿色圆形按钮或已签到状态
                        if store.isCheckedInToday() {
                            // 已签到状态
                            ZStack {
                                // 外圈光晕效果（灰色）
                                Circle()
                                    .fill(Color(red: 0.7, green: 0.7, blue: 0.7).opacity(0.15))
                                    .frame(width: 300, height: 300)
                                
                                Circle()
                                    .fill(Color(red: 0.7, green: 0.7, blue: 0.7).opacity(0.25))
                                    .frame(width: 260, height: 260)
                                
                                Circle()
                                    .fill(Color(red: 0.7, green: 0.7, blue: 0.7).opacity(0.35))
                                    .frame(width: 220, height: 220)
                                
                                // 主按钮（灰色）
                                Circle()
                                    .fill(Color(red: 0.7, green: 0.7, blue: 0.7))
                                    .frame(width: 180, height: 180)
                                
                                VStack(spacing: 12) {
                                    // 成功图标
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 30, weight: .bold))
                                            .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                                    }
                                    
                                    Text("今日已签到")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.top, 30)
                            .padding(.bottom, 20)
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
                                        .fill(Color(red: 0.2, green: 0.7, blue: 0.3).opacity(0.15))
                                        .frame(width: 300, height: 300)
                                    
                                    Circle()
                                        .fill(Color(red: 0.2, green: 0.7, blue: 0.3).opacity(0.25))
                                        .frame(width: 260, height: 260)
                                    
                                    Circle()
                                        .fill(Color(red: 0.2, green: 0.7, blue: 0.3).opacity(0.35))
                                        .frame(width: 220, height: 220)
                                    
                                    // 主按钮
                                    Circle()
                                        .fill(Color(red: 0.2, green: 0.7, blue: 0.3))
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
                                                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.3))
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
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.top, 30)
                            .padding(.bottom, 20)
                        }
                        
                        // 警告信息
                        HStack(alignment: .top, spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.2, green: 0.7, blue: 0.3))
                                    .frame(width: 24, height: 24)
                                
                                Text("①")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("多日未签到, 系统将以你的名义, 在次日邮件通知你的紧急联系人")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        
                        // 协议链接
                        HStack(spacing: 4) {
                            Text("签到即同意")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                showTermsOfService = true
                            }) {
                                Text("用户协议")
                                    .font(.system(size: 12))
                                    .foregroundColor(primaryGreen)
                            }
                            
                            Text("和")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                showPrivacyPolicy = true
                            }) {
                                Text("隐私政策")
                                    .font(.system(size: 12))
                                    .foregroundColor(primaryGreen)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
}
