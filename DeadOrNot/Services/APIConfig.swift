import Foundation

struct APIConfig {
    #if DEBUG
    static let baseURL = "http://127.0.0.1:8080/api"
    #else
    static let baseURL = "https://alive.xiaodao.fun/api"
    #endif
}
