import Foundation
import Combine

@MainActor
final class UserInfo: ObservableObject {
    @Published var name: String = "" {
        didSet {
            if !isLoading {
                saveToStorage()
            }
        }
    }
    
    @Published var emergencyContactEmails: [String] = [] {
        didSet {
            // 限制最多3个联系人
            if emergencyContactEmails.count > 3 {
                emergencyContactEmails = Array(emergencyContactEmails.prefix(3))
            }
            if !isLoading {
                saveToStorage()
            }
        }
    }
    
    private var isLoading = false
    private let userDefaultsKeyName = "DeadOrNot.userName"
    private let userDefaultsKeyEmails = "DeadOrNot.emergencyContactEmails"
    private let apiService = APIService.shared
    
    init() {
        loadFromStorage()
        Task {
            await loadFromServer()
        }
    }
    
    private func loadFromStorage() {
        isLoading = true
        defer { isLoading = false }
        
        name = UserDefaults.standard.string(forKey: userDefaultsKeyName) ?? ""
        if let emails = UserDefaults.standard.array(forKey: userDefaultsKeyEmails) as? [String] {
            emergencyContactEmails = emails
        }
    }
    
    private func saveToStorage() {
        UserDefaults.standard.set(name, forKey: userDefaultsKeyName)
        UserDefaults.standard.set(emergencyContactEmails, forKey: userDefaultsKeyEmails)
        // 确保立即同步到磁盘
        UserDefaults.standard.synchronize()
    }
    
    func saveToServer() async {
        let timezone = TimeZone.current.identifier
        do {
            try await apiService.updateUser(
                name: name.isEmpty ? nil : name,
                emails: emergencyContactEmails.isEmpty ? nil : emergencyContactEmails,
                timezone: timezone
            )
        } catch {
            print("Failed to save user info to server: \(error.localizedDescription)")
        }
    }
    
    private func loadFromServer() async {
        do {
            let user = try await apiService.getUser()
            isLoading = true
            
            // 如果服务器有数据，优先使用服务器数据
            if !user.name.isEmpty {
                name = user.name
            }
            if !user.emergencyContactEmails.isEmpty {
                emergencyContactEmails = user.emergencyContactEmails
            }
            
            saveToStorage()
            isLoading = false
        } catch {
            // 网络错误时保持使用本地数据
            print("Failed to load user info from server: \(error.localizedDescription)")
        }
    }
    
    func isSetupComplete() -> Bool {
        !name.isEmpty && !emergencyContactEmails.isEmpty && emergencyContactEmails.allSatisfy { !$0.isEmpty }
    }
    
    func addEmergencyContact(_ email: String) {
        guard !email.isEmpty, !emergencyContactEmails.contains(email), emergencyContactEmails.count < 3 else {
            return
        }
        emergencyContactEmails.append(email)
    }
    
    func removeEmergencyContact(at index: Int) {
        guard index >= 0 && index < emergencyContactEmails.count else { return }
        emergencyContactEmails.remove(at: index)
    }
    
    func updateEmergencyContact(at index: Int, email: String) {
        guard index >= 0 && index < emergencyContactEmails.count else { return }
        emergencyContactEmails[index] = email
    }
    
    func maskedName() -> String {
        guard !name.isEmpty else { return "" }
        if name.count <= 1 {
            return name
        }
        let firstChar = String(name.prefix(1))
        return firstChar + "*"
    }
    
    func maskedEmails() -> [String] {
        return emergencyContactEmails.map { email in
            guard !email.isEmpty else { return "" }
            let components = email.split(separator: "@")
            guard components.count == 2 else { return email }
            
            let username = String(components[0])
            let domain = String(components[1])
            
            if username.count <= 5 {
                return String(repeating: "*", count: username.count) + "@" + domain
            }
            
            let prefix = String(username.prefix(5))
            return prefix + "***@" + domain
        }
    }
}
