import Foundation

// MARK: - Token Response
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int64

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

@MainActor
final class APIService {
    static let shared = APIService()

    private let session: URLSession
    private let deviceID: String

    // Token 存储键
    private let accessTokenKey = "DeadOrNot.accessToken"
    private let refreshTokenKey = "DeadOrNot.refreshToken"
    private let tokenExpiresAtKey = "DeadOrNot.tokenExpiresAt"

    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: accessTokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: accessTokenKey) }
    }

    var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: refreshTokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: refreshTokenKey) }
    }

    var tokenExpiresAt: Date? {
        get { UserDefaults.standard.object(forKey: tokenExpiresAtKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: tokenExpiresAtKey) }
    }

    var isLoggedIn: Bool {
        accessToken != nil && refreshToken != nil
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.deviceID = DeviceIDManager.shared.deviceID
    }

    // MARK: - Auth

    func login() async throws {
        struct LoginRequest: Codable {
            let deviceID: String

            enum CodingKeys: String, CodingKey {
                case deviceID = "device_id"
            }
        }

        // 先尝试使用现有 token，如果已失效则重新登录
        if self.refreshToken != nil {
            do {
                try await refreshAccessToken()
                return
            } catch {
                // 继续执行登录流程
            }
        }

        // 执行登录
        let request = LoginRequest(deviceID: deviceID)

        struct LoginResponse: Codable {
            let accessToken: String
            let refreshToken: String
            let tokenType: String
            let expiresIn: Int64

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case tokenType = "token_type"
                case expiresIn = "expires_in"
            }
        }

        let response: LoginResponse = try await makeAuthRequest(endpoint: "/auth/login", method: "POST", body: request)

        // 保存 token
        self.accessToken = response.accessToken
        self.refreshToken = response.refreshToken
        self.tokenExpiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
    }

    func logout() async throws {
        guard accessToken != nil else { return }

        struct EmptyRequest: Codable {}

        // 不等待响应，直接清除本地 token
        do {
            _ = try await makeAuthRequest(endpoint: "/auth/logout", method: "POST")
        } catch {
            // 忽略错误
        }

        clearTokens()
    }

    func refreshAccessToken() async throws {
        guard let refreshToken = self.refreshToken else {
            throw APIError.unauthorized
        }

        struct RefreshRequest: Codable {
            let refreshToken: String

            enum CodingKeys: String, CodingKey {
                case refreshToken = "refresh_token"
            }
        }

        let request = RefreshRequest(refreshToken: refreshToken)

        struct RefreshResponse: Codable {
            let accessToken: String
            let refreshToken: String
            let tokenType: String
            let expiresIn: Int64

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case tokenType = "token_type"
                case expiresIn = "expires_in"
            }
        }

        let response: RefreshResponse = try await makeAuthRequest(endpoint: "/auth/refresh", method: "POST", body: request)

        // 更新 token
        self.accessToken = response.accessToken
        self.refreshToken = response.refreshToken
        self.tokenExpiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
    }

    private func clearTokens() {
        accessToken = nil
        refreshToken = nil
        tokenExpiresAt = nil
    }

    // MARK: - Private Helpers

    private func makeAuthRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil
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
    }

    private func makeRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        retryOnUnauthorized: Bool = true
    ) async throws -> T {
        // 确保已登录
        if !isLoggedIn {
            try await login()
        }

        // 检查 token 是否即将过期（5分钟内），如果是则刷新
        if let expiresAt = tokenExpiresAt, expiresAt.timeIntervalSinceNow < 300 {
            try await refreshAccessToken()
        }

        guard let url = URL(string: "\(APIConfig.baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 添加 Bearer Token
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.decodingError(error)
            }
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        // 如果是 401，尝试刷新 token 并重试
        if httpResponse.statusCode == 401 && retryOnUnauthorized {
            do {
                try await refreshAccessToken()
                return try await makeRequest(endpoint: endpoint, method: method, body: body, retryOnUnauthorized: false) as! T
            } catch {
                // 刷新失败，重新登录
                clearTokens()
                try await login()
                return try await makeRequest(endpoint: endpoint, method: method, body: body, retryOnUnauthorized: false) as! T
            }
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
    }

    // MARK: - CheckIn APIs

    func checkIn(datetime: String? = nil) async throws -> CheckInResponse {
        struct CheckInRequest: Codable {
            let datetime: String?
        }

        let datetimeString: String
        if let datetime = datetime {
            datetimeString = datetime
        } else {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
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

    func updateUser(name: String? = nil, emails: [String]? = nil, timezone: String? = nil, apnsToken: String? = nil, pushEnabled: Bool? = nil) async throws {
        struct UpdateUserRequest: Codable {
            let name: String?
            let emergencyContactEmails: [String]?
            let timezone: String?
            let apnsToken: String?
            let pushEnabled: Bool?

            enum CodingKeys: String, CodingKey {
                case name
                case emergencyContactEmails = "emergency_contact_emails"
                case timezone
                case apnsToken = "apns_token"
                case pushEnabled = "push_enabled"
            }
        }

        struct UpdateUserResponse: Codable {
            let message: String?
        }

        let request = UpdateUserRequest(name: name, emergencyContactEmails: emails, timezone: timezone, apnsToken: apnsToken, pushEnabled: pushEnabled)
        let _: UpdateUserResponse = try await makeRequest(endpoint: "/user", method: "PUT", body: request)
    }
}

// MARK: - API Error Extension
extension APIError {
    static let unauthorized = APIError.serverError(401, "Unauthorized")
}
