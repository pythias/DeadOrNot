import SwiftUI

struct SetupView: View {
    @ObservedObject var userInfo: UserInfo
    @Binding var isSetupComplete: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var workingEmails: [String] = []
    @Environment(\.dismiss) private var dismiss
    
    private var backgroundColor: Color {
        colorScheme == .dark 
            ? Color(red: 0.1, green: 0.15, blue: 0.1)
            : Color(red: 0.9, green: 0.95, blue: 0.9)
    }
    
    private var inputBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(red: 0.2, green: 0.2, blue: 0.2)
            : Color.white
    }
    
    private var primaryGreen: Color {
        Color(red: 0.2, green: 0.7, blue: 0.3)
    }
    
    var body: some View {
        ZStack {
            // 背景色，根据深色模式适配
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部关闭按钮
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(primaryGreen)
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 60)
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 姓名输入框
                        VStack(alignment: .leading, spacing: 8) {
                            Text("你的姓名")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 24)
                            
                            ZStack(alignment: .leading) {
                                HStack {
                                    Text(userInfo.name.isEmpty ? "请输入姓名" : "")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                
                                TextField("", text: $userInfo.name)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                            }
                            .background(inputBackgroundColor)
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                        }
                        .padding(.top, 20)
                        
                        // 紧急联系人输入框
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("紧急联系人邮箱")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(workingEmails.filter { !$0.isEmpty }.count)/3")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 24)
                            
                            ForEach(0..<workingEmails.count, id: \.self) { index in
                                HStack(spacing: 12) {
                                    ZStack(alignment: .leading) {
                                        HStack {
                                            Text(workingEmails[index].isEmpty ? "请输入邮箱" : "")
                                                .font(.system(size: 16))
                                                .foregroundColor(.secondary)
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                        
                                        TextField("", text: Binding(
                                            get: { workingEmails[index] },
                                            set: { newValue in
                                                workingEmails[index] = newValue
                                            }
                                        ))
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                    }
                                    .background(inputBackgroundColor)
                                    .cornerRadius(12)
                                    
                                    if workingEmails.count > 1 {
                                        Button(action: {
                                            workingEmails.remove(at: index)
                                            if workingEmails.isEmpty {
                                                workingEmails.append("")
                                            }
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(Color(red: 0.8, green: 0.3, blue: 0.3))
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            if workingEmails.count < 3 {
                                Button(action: {
                                    workingEmails.append("")
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 16))
                                        Text("添加联系人")
                                            .font(.system(size: 16))
                                    }
                                    .foregroundColor(primaryGreen)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(inputBackgroundColor)
                                    .cornerRadius(12)
                                    .padding(.horizontal, 24)
                                }
                            }
                        }
                        .padding(.top, 10)
                        
                        // 完成按钮
                        Button(action: {
                            // 保存所有非空邮箱
                            let validEmails = workingEmails.filter { !$0.isEmpty }
                            userInfo.emergencyContactEmails = validEmails
                            
                            // 提交到服务器，完成后关闭
                            Task {
                                await userInfo.saveToServer()
                                dismiss()
                            }
                        }) {
                            Text("完成设置")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canComplete() ? primaryGreen : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!canComplete())
                        .padding(.horizontal, 24)
                        .padding(.top, 30)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            // 初始化工作邮箱列表
            // 如果已有保存的邮箱，使用保存的；否则创建一个空输入框
            if userInfo.emergencyContactEmails.isEmpty {
                workingEmails = [""]
            } else {
                // 使用保存的邮箱，确保至少有一个输入框
                workingEmails = userInfo.emergencyContactEmails
                if workingEmails.isEmpty {
                    workingEmails = [""]
                }
            }
        }
    }
    
    private func canComplete() -> Bool {
        !userInfo.name.isEmpty && !workingEmails.filter { !$0.isEmpty }.isEmpty
    }
}
