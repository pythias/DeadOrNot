import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: CheckInStore
    @EnvironmentObject var userInfo: UserInfo
    @State private var showSetup = false
    @State private var showSuccessAnimation = false
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    
    private var primaryGreen: Color {
        Color(red: 0.2, green: 0.7, blue: 0.3)
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
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(width: 300, height: 300)
                                
                                Circle()
                                    .fill(Color.secondary.opacity(0.25))
                                    .frame(width: 260, height: 260)
                                
                                Circle()
                                    .fill(Color.secondary.opacity(0.35))
                                    .frame(width: 220, height: 220)
                                
                                // 主按钮
                                Circle()
                                    .fill(Color.secondary)
                                    .frame(width: 180, height: 180)
                                
                                VStack(spacing: 12) {
                                    // 成功图标
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 30, weight: .bold))
                                            .foregroundColor(Color.secondary)
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
                                .fill(Color.secondary.opacity(0.1))
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


