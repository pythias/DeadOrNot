import SwiftUI

struct SetupView: View {
  @ObservedObject var userInfo: UserInfo
  @Binding var isSetupComplete: Bool
  @State private var workingEmails: [String] = []
  @State private var nameError: String? = nil
  @State private var emailErrors: [Int: String] = [:]
  @Environment(\.dismiss) private var dismiss

  // 是否是独立页面（首次进入），还是通过导航栏进入的 sheet
  var isStandalone: Bool = false

  private var primaryGreen: Color {
    Color(red: 0.2, green: 0.7, blue: 0.3)
  }

  var body: some View {
    Form {
      // 姓名输入框
      Section {
        TextField("请输入姓名", text: $userInfo.name)
          .textInputAutocapitalization(.words)
          .onChange(of: userInfo.name) { _, newValue in
            validateName(newValue)
          }
        
        if let error = nameError {
          Text(error)
            .font(.caption)
            .foregroundColor(.red)
        }
      } header: {
        Text("你的姓名")
      } footer: {
        if nameError == nil {
          Text("姓名需要2-10个字符")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      // 紧急联系人输入框
      Section {
        ForEach(0..<workingEmails.count, id: \.self) { index in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              TextField(
                "请输入邮箱",
                text: Binding(
                  get: { workingEmails[index] },
                  set: { newValue in
                    workingEmails[index] = newValue
                    validateEmail(newValue, at: index)
                  }
                )
              )
              .keyboardType(.emailAddress)
              .autocapitalization(.none)
              .textContentType(.emailAddress)

              if workingEmails.count > 1 {
                Button(action: {
                  emailErrors.removeValue(forKey: index)
                  workingEmails.remove(at: index)
                  // 重新索引错误信息：删除索引后的所有错误索引减1
                  var newErrors: [Int: String] = [:]
                  for (key, value) in emailErrors {
                    if key > index {
                      newErrors[key - 1] = value
                    } else if key < index {
                      newErrors[key] = value
                    }
                  }
                  emailErrors = newErrors
                  if workingEmails.isEmpty {
                    workingEmails.append("")
                  }
                }) {
                  Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
              }
            }
            
            if let error = emailErrors[index] {
              Text(error)
                .font(.caption)
                .foregroundColor(.red)
            }
          }
        }

        if workingEmails.count < 3 {
          Button(action: {
            workingEmails.append("")
          }) {
            HStack {
              Image(systemName: "plus.circle.fill")
              Text("添加联系人")
            }
          }
        }
      } header: {
        Text("紧急联系人邮箱")
      } footer: {
        Text("已添加 \(workingEmails.filter { !$0.isEmpty }.count)/3 个联系人")
      }

      // 完成按钮（仅在独立页面时显示在底部）
      if isStandalone {
        Section {
          Button(action: {
            saveAndComplete()
          }) {
            HStack {
              Spacer()
              Text("完成设置")
                .font(.headline)
                .fontWeight(.semibold)
              Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
          }
          .listRowBackground(canComplete() ? primaryGreen : Color.secondary.opacity(0.3))
          .disabled(!canComplete())
        }
      }
    }
    .navigationTitle("设置")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        if !isStandalone {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    saveAndComplete()
                }
                .foregroundColor(canComplete() ? primaryGreen : .secondary)
                .disabled(!canComplete())
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
      // 验证已有数据
      validateName(userInfo.name)
      for (index, email) in workingEmails.enumerated() {
        if !email.isEmpty {
          validateEmail(email, at: index)
        }
      }
    }
  }

  private func canComplete() -> Bool {
    // 名字必须有效（2-10个字符）
    guard nameError == nil, userInfo.name.count >= 2, userInfo.name.count <= 10 else {
      return false
    }
    
    // 至少有一个有效的邮箱
    let validEmails = workingEmails.filter { email in
      !email.isEmpty && isValidEmail(email)
    }
    
    guard !validEmails.isEmpty else {
      return false
    }
    
    // 所有非空邮箱必须有效
    let nonEmptyEmails = workingEmails.filter { !$0.isEmpty }
    return nonEmptyEmails.allSatisfy { isValidEmail($0) }
  }
  
  private func validateName(_ name: String) {
    if name.isEmpty {
      nameError = nil
    } else if name.count < 2 {
      nameError = "姓名至少需要2个字符"
    } else if name.count > 10 {
      nameError = "姓名不能超过10个字符"
    } else {
      nameError = nil
    }
  }
  
  private func validateEmail(_ email: String, at index: Int) {
    if email.isEmpty {
      emailErrors.removeValue(forKey: index)
    } else if !isValidEmail(email) {
      emailErrors[index] = "请输入有效的邮箱地址"
    } else {
      emailErrors.removeValue(forKey: index)
    }
  }
  
  private func isValidEmail(_ email: String) -> Bool {
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: email)
  }

  private func saveAndComplete() {
    // 保存所有有效的邮箱（非空且格式正确）
    let validEmails = workingEmails.filter { email in
      !email.isEmpty && isValidEmail(email)
    }
    userInfo.emergencyContactEmails = validEmails

    // 提交到服务器
    Task {
      await userInfo.saveToServer()
      // 如果是 sheet 模式，关闭 sheet
      // 如果是独立页面，通过 isSetupComplete 的变化自动跳转到打卡页
      dismiss()
    }
  }
}
