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

    private var tokenFileURL: URL? {
        #if os(macOS)
        guard let baseDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        #elseif os(iOS)
        guard let baseDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        #endif
        let appFolder = baseDir.appendingPathComponent("SendOnly", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: appFolder.path) {
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }

        return appFolder.appendingPathComponent("tokens.json")
    }

    private init() {}

    // MARK: - Token Storage

    func saveTokens(_ tokens: OAuthTokens) throws {
        guard let fileURL = tokenFileURL else {
            throw KeychainError.fileError("Could not get token file URL")
        }

        let data = try JSONEncoder().encode(tokens)
        try data.write(to: fileURL, options: .atomic)
    }

    func loadTokens() throws -> OAuthTokens {
        guard let fileURL = tokenFileURL else {
            throw KeychainError.fileError("Could not get token file URL")
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw KeychainError.itemNotFound
        }

        let data = try Data(contentsOf: fileURL)
        let tokens = try JSONDecoder().decode(OAuthTokens.self, from: data)
        return tokens
    }

    func deleteTokens() throws {
        guard let fileURL = tokenFileURL else {
            return
        }

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
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
