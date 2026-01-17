import Foundation

@MainActor
final class APIService {
    static let shared = APIService()
    
    private let session: URLSession
    private let deviceID: String
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.deviceID = DeviceIDManager.shared.deviceID
    }
    
    // MARK: - Private Helpers
    
    private func makeRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(APIConfig.baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.decodingError(error)
            }
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.unknown
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)["error"]
                throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }
            
            guard !data.isEmpty else {
                throw APIError.noData
            }
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - CheckIn APIs
    
    func checkIn(datetime: String? = nil) async throws -> CheckInResponse {
        struct CheckInRequest: Codable {
            let datetime: String?
        }
        
        // 如果没有提供 datetime，使用当前时间的 RFC 3339 格式
        let datetimeString: String
        if let datetime = datetime {
            datetimeString = datetime
        } else {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime] // RFC 3339 标准格式
            formatter.timeZone = TimeZone.current
            datetimeString = formatter.string(from: Date())
        }
        
        let request = CheckInRequest(datetime: datetimeString)
        return try await makeRequest(endpoint: "/checkin", method: "POST", body: request)
    }
    
    func getCheckInHistory(startDate: String? = nil, endDate: String? = nil) async throws -> [String] {
        var endpoint = "/checkin/history"
        var queryItems: [URLQueryItem] = []
        
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: startDate))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: endDate))
        }
        
        if !queryItems.isEmpty {
            var components = URLComponents()
            components.queryItems = queryItems
            if let queryString = components.url?.query {
                endpoint += "?" + queryString
            }
        }
        
        struct HistoryResponse: Codable {
            let datetimes: [String]
        }
        
        let response: HistoryResponse = try await makeRequest(endpoint: endpoint)
        return response.datetimes
    }
    
    func getCheckInStats() async throws -> CheckInStats {
        return try await makeRequest(endpoint: "/checkin/stats")
    }
    
    // MARK: - User APIs
    
    func getUser() async throws -> User {
        return try await makeRequest(endpoint: "/user")
    }
    
    func updateUser(name: String? = nil, emails: [String]? = nil, timezone: String? = nil) async throws {
        struct UpdateUserRequest: Codable {
            let name: String?
            let emergencyContactEmails: [String]?
            let timezone: String?
            
            enum CodingKeys: String, CodingKey {
                case name
                case emergencyContactEmails = "emergency_contact_emails"
                case timezone
            }
        }
        
        struct UpdateUserResponse: Codable {
            let message: String?
        }
        
        let request = UpdateUserRequest(name: name, emergencyContactEmails: emails, timezone: timezone)
        let _: UpdateUserResponse = try await makeRequest(endpoint: "/user", method: "PUT", body: request)
    }
}
