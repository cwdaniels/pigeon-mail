import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case invalidData
    case fileError(String)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found"
        case .duplicateItem:
            return "Item already exists"
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        case .invalidData:
            return "Invalid data format"
        case .fileError(let message):
            return "File error: \(message)"
        }
    }
}

final class KeychainService {
    static let shared = KeychainService()

    private let fileManager = FileManager.default
    private let keychainService = "com.sendonly.app.tokens"
    private let keychainAccount = "oauth-tokens"

    #if os(macOS)
    private var tokenFileURL: URL? {
        guard let baseDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appFolder = baseDir.appendingPathComponent("SendOnly", isDirectory: true)

        if !fileManager.fileExists(atPath: appFolder.path) {
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }

        return appFolder.appendingPathComponent("tokens.json")
    }
    #endif

    private init() {}

    // MARK: - Token Storage

    func saveTokens(_ tokens: OAuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)

        #if os(iOS)
        try saveToKeychain(data)
        #else
        guard let fileURL = tokenFileURL else {
            throw KeychainError.fileError("Could not get token file URL")
        }
        try data.write(to: fileURL, options: .atomic)
        #endif
    }

    func loadTokens() throws -> OAuthTokens {
        #if os(iOS)
        let data = try loadFromKeychain()
        return try JSONDecoder().decode(OAuthTokens.self, from: data)
        #else
        guard let fileURL = tokenFileURL else {
            throw KeychainError.fileError("Could not get token file URL")
        }
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw KeychainError.itemNotFound
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(OAuthTokens.self, from: data)
        #endif
    }

    func deleteTokens() throws {
        #if os(iOS)
        deleteFromKeychain()
        #else
        guard let fileURL = tokenFileURL else {
            return
        }
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        #endif
    }

    // MARK: - iOS Keychain Operations

    #if os(iOS)
    private func saveToKeychain(_ data: Data) throws {
        // Delete existing item first
        deleteFromKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func loadFromKeychain() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainError.itemNotFound
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)
    }
    #endif
}

// MARK: - OAuth Tokens Model

struct OAuthTokens: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: Int
    let scope: String?
    let expiresAt: Date

    init(accessToken: String, refreshToken: String?, tokenType: String, expiresIn: Int, scope: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.scope = scope
        self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
    }

    var isExpired: Bool {
        // Consider expired 5 minutes before actual expiry
        Date() >= expiresAt.addingTimeInterval(-300)
    }
}

// Response from Google's token endpoint
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: Int
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }

    func toOAuthTokens() -> OAuthTokens {
        OAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresIn: expiresIn,
            scope: scope
        )
    }
}
