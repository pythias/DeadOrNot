import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark 
            ? Color(red: 0.1, green: 0.15, blue: 0.1)
            : Color(red: 0.9, green: 0.95, blue: 0.9)
    }
    
    private var primaryGreen: Color {
        Color(red: 0.2, green: 0.7, blue: 0.3)
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("返回")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(primaryGreen)
                    }
                    
                    Spacer()
                    
                    Text("用户协议")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 占位，保持标题居中
                    Color.clear
                        .frame(width: 60)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("用户协议")
                            .font(.system(size: 24, weight: .bold))
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                        
                        Text("生效日期：2024年1月1日")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            SectionView(
                                title: "1. 服务说明",
                                content: """
                                欢迎使用本应用。本应用提供每日签到功能，帮助用户记录日常活动状态。当用户连续多日未签到时，系统将自动向用户预设的紧急联系人发送通知邮件。
                                
                                使用本应用即表示您同意遵守本用户协议的所有条款和条件。
                                """
                            )
                            
                            SectionView(
                                title: "2. 用户责任",
                                content: """
                                2.1 您有责任确保提供的个人信息（包括姓名和紧急联系人邮箱）真实、准确、完整。
                                
                                2.2 您有责任妥善保管您的账户信息，不得将账户信息泄露给第三方。
                                
                                2.3 您理解并同意，本应用仅作为工具使用，不承担因使用本应用而产生的任何直接或间接损失。
                                """
                            )
                            
                            SectionView(
                                title: "3. 服务使用",
                                content: """
                                3.1 您有权使用本应用提供的签到功能。
                                
                                3.2 您理解并同意，当您连续多日未签到时，系统将按照您的设置向紧急联系人发送通知邮件。
                                
                                3.3 您有权随时修改或删除您的个人信息和紧急联系人信息。
                                """
                            )
                            
                            SectionView(
                                title: "4. 服务变更与终止",
                                content: """
                                4.1 我们保留随时修改、暂停或终止本服务的权利，无需提前通知。
                                
                                4.2 如果您违反本协议的任何条款，我们有权立即终止向您提供服务。
                                """
                            )
                            
                            SectionView(
                                title: "5. 免责声明",
                                content: """
                                5.1 本应用按"现状"提供，不提供任何明示或暗示的保证。
                                
                                5.2 我们不对因使用或无法使用本应用而造成的任何损害承担责任，包括但不限于直接、间接、偶然或后果性损害。
                                
                                5.3 我们不对邮件发送的及时性、准确性或送达性做出任何保证。
                                """
                            )
                            
                            SectionView(
                                title: "6. 协议修改",
                                content: """
                                我们保留随时修改本协议的权利。修改后的协议将在应用内公布，继续使用本应用即视为您接受修改后的协议。
                                """
                            )
                            
                            SectionView(
                                title: "7. 适用法律",
                                content: """
                                本协议的订立、执行和解释及争议的解决均应适用中华人民共和国法律。
                                """
                            )
                            
                            SectionView(
                                title: "8. 联系我们",
                                content: """
                                如您对本协议有任何疑问，请通过应用内设置页面联系我们。
                                """
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
}

struct SectionView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(content)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
    }
}
