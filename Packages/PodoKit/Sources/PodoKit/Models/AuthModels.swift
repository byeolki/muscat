import Foundation

struct BootstrapRequest: Encodable {
    let name: String
    let email: String
    let password: String
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let name: String
    let email: String
    let password: String
    let inviteToken: String
}

struct RefreshRequest: Encodable {
    let refreshToken: String
}

struct LogoutRequest: Encodable {
    let refreshToken: String
}

struct UpdateMeRequest: Encodable {
    let name: String?
    let currentPassword: String?
    let newPassword: String?
}

struct TokenPair: Codable {
    let accessToken: String
    let refreshToken: String
}

public enum UserRole: String, Codable {
    case admin
    case user
}

public struct MeResponse: Codable, Identifiable {
    public let id: String
    public let name: String
    public let email: String
    public let role: UserRole
    public let createdAt: Date
}
