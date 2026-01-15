import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("隐私政策")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("生效日期：2024年1月1日")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    SectionView(
                        title: "1. 信息收集",
                        content: """
                        我们收集以下信息以提供本应用的核心功能：
                        
                        • 姓名：用于标识用户身份
                        • 紧急联系人邮箱：用于在您连续多日未签到时发送通知邮件
                        • 签到记录：用于记录您的每日签到状态
                        
                        所有信息均存储在您的设备本地，我们不会将您的个人信息上传至任何服务器。
                        """
                    )
                    
                    SectionView(
                        title: "2. 信息使用",
                        content: """
                        我们使用收集的信息仅用于以下目的：
                        
                        • 提供每日签到功能
                        • 记录您的签到历史
                        • 在您连续多日未签到时，向您预设的紧急联系人发送通知邮件
                        
                        我们不会将您的个人信息用于任何其他商业目的，也不会向第三方出售、交易或出租您的个人信息。
                        """
                    )
                    
                    SectionView(
                        title: "3. 信息存储",
                        content: """
                        3.1 所有个人信息和签到记录均存储在您的设备本地，使用 iOS 系统的标准存储机制。
                        
                        3.2 我们不会在服务器上存储您的任何个人信息。
                        
                        3.3 当您卸载本应用时，所有本地存储的数据将被删除。
                        """
                    )
                    
                    SectionView(
                        title: "4. 信息共享",
                        content: """
                        4.1 我们不会与任何第三方共享您的个人信息，除非：
                        • 法律法规要求
                        • 获得您的明确同意
                        
                        4.2 邮件发送功能通过系统邮件服务实现，邮件内容仅包含必要的通知信息，不包含您的其他个人信息。
                        """
                    )
                    
                    SectionView(
                        title: "5. 数据安全",
                        content: """
                        5.1 我们采用 iOS 系统提供的标准安全机制来保护您的个人信息。
                        
                        5.2 所有数据存储在设备本地，不会通过网络传输。
                        
                        5.3 我们建议您定期备份您的设备数据，以防数据丢失。
                        """
                    )
                    
                    SectionView(
                        title: "6. 您的权利",
                        content: """
                        您对您的个人信息享有以下权利：
                        
                        • 访问权：您可以随时在应用内查看您的个人信息
                        • 修改权：您可以随时修改或更新您的个人信息
                        • 删除权：您可以随时删除您的个人信息和签到记录
                        • 撤回同意权：您可以随时停止使用本应用，并删除所有数据
                        """
                    )
                    
                    SectionView(
                        title: "7. 未成年人保护",
                        content: """
                        本应用不面向未满18周岁的未成年人提供服务。如果您是未成年人，请在监护人的陪同下阅读本隐私政策，并在征得监护人同意后使用本应用。
                        """
                    )
                    
                    SectionView(
                        title: "8. 隐私政策更新",
                        content: """
                        我们可能会不定期更新本隐私政策。更新后的隐私政策将在应用内公布，继续使用本应用即视为您接受更新后的隐私政策。
                        """
                    )
                    
                    SectionView(
                        title: "9. 联系我们",
                        content: """
                        如您对本隐私政策有任何疑问、意见或建议，或需要行使您的相关权利，请通过应用内设置页面联系我们。
                        """
                    )
                }
            }
            .navigationTitle("隐私政策")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
