import Foundation

// MARK: - CheckIn Response
struct CheckInResponse: Codable {
    let message: String
    let date: String
}

// MARK: - CheckIn Stats
struct CheckInStats: Codable {
    let currentStreak: Int
    let lastCheckinDate: String?
    let totalDays: Int
    
    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case lastCheckinDate = "last_checkin_date"
        case totalDays = "total_days"
    }
}

// MARK: - User
struct User: Codable {
    let id: Int64
    let deviceID: String
    var name: String
    var emergencyContactEmails: [String]
    let apnsToken: String?
    var pushEnabled: Bool
    var emailEnabled: Bool
    var timezone: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case deviceID = "device_id"
        case name
        case emergencyContactEmails = "emergency_contact_emails"
        case apnsToken = "apns_token"
        case pushEnabled = "push_enabled"
        case emailEnabled = "email_enabled"
        case timezone
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case serverError(Int, String?)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}
