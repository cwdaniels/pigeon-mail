import Foundation
import CryptoKit

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
import AuthenticationServices
#endif

enum AuthError: Error, LocalizedError {
    case configurationMissing
    case invalidURL
    case authenticationFailed(String)
    case tokenExchangeFailed(String)
    case noRefreshToken
    case networkError(Error)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "OAuth configuration is missing. Please add your Client ID in Settings."
        case .invalidURL:
            return "Failed to construct authorization URL"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .tokenExchangeFailed(let message):
            return "Token exchange failed: \(message)"
        case .noRefreshToken:
            return "No refresh token available"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var userEmail: String?
    @Published private(set) var userName: String?
    @Published private(set) var isLoading = false
    @Published var error: AuthError?

    var formattedFromAddress: String {
        if let name = userName, !name.isEmpty, let email = userEmail {
            return "\(name) <\(email)>"
        }
        return userEmail ?? ""
    }

    private let keychain = KeychainService.shared
    private var tokens: OAuthTokens?

    // OAuth Configuration
    private var clientId: String = ""
    private var clientSecret: String = ""

    #if os(macOS)
    // Use loopback for Google Desktop OAuth
    private var redirectPort: UInt16 = 8089
    private var redirectURI: String {
        "http://127.0.0.1:\(redirectPort)"
    }
    // Local server for OAuth callback
    private var callbackServer: CallbackServer?
    #elseif os(iOS)
    // iOS uses reversed Google client ID as URL scheme
    private static let iOSClientId = "625756953176-i51iif2paf25qp7nssb1fh6lb3t16njm.apps.googleusercontent.com"
    private static let iOSCallbackScheme = "com.googleusercontent.apps.625756953176-i51iif2paf25qp7nssb1fh6lb3t16njm"
    private var redirectURI: String {
        "\(Self.iOSCallbackScheme):/oauth2callback"
    }
    #endif

    private let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private let tokenEndpoint = "https://oauth2.googleapis.com/token"
    private let userInfoEndpoint = "https://www.googleapis.com/oauth2/v2/userinfo"

    private let scopes = [
        "https://www.googleapis.com/auth/gmail.send",
        "https://www.googleapis.com/auth/gmail.compose",
        "https://www.googleapis.com/auth/contacts.readonly",
        "https://www.googleapis.com/auth/directory.readonly",
        "https://www.googleapis.com/auth/userinfo.email"
    ]

    // PKCE
    private var codeVerifier: String?

    private init() {
        loadConfiguration()
        loadStoredTokens()
    }

    // MARK: - Configuration

    private func loadConfiguration() {
        #if os(iOS)
        // iOS uses a dedicated iOS OAuth client (no client secret needed)
        self.clientId = Self.iOSClientId
        self.clientSecret = ""
        #else
        // macOS: load from credentials.json in bundle
        if let url = Bundle.main.url(forResource: "credentials", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let installed = json["installed"] as? [String: Any] ?? json["web"] as? [String: Any],
           let clientId = installed["client_id"] as? String {
            self.clientId = clientId
            self.clientSecret = installed["client_secret"] as? String ?? ""
        } else {
            // Fallback to UserDefaults for manual configuration
            clientId = UserDefaults.standard.string(forKey: "oauth_client_id") ?? ""
            clientSecret = UserDefaults.standard.string(forKey: "oauth_client_secret") ?? ""
        }
        #endif
    }

    func configure(clientId: String, clientSecret: String = "") {
        self.clientId = clientId
        self.clientSecret = clientSecret
        UserDefaults.standard.set(clientId, forKey: "oauth_client_id")
        UserDefaults.standard.set(clientSecret, forKey: "oauth_client_secret")
    }

    var isConfigured: Bool {
        !clientId.isEmpty
    }

    // MARK: - Token Management

    private func loadStoredTokens() {
        do {
            tokens = try keychain.loadTokens()
            isAuthenticated = true
            Task {
                await fetchUserInfo()
            }
        } catch {
            tokens = nil
            isAuthenticated = false
        }
    }

    func getAccessToken() async throws -> String {
        guard let tokens = tokens else {
            throw AuthError.authenticationFailed("Not authenticated")
        }

        if tokens.isExpired {
            try await refreshAccessToken()
        }

        return self.tokens?.accessToken ?? tokens.accessToken
    }

    private func refreshAccessToken() async throws {
        guard let refreshToken = tokens?.refreshToken else {
            throw AuthError.noRefreshToken
        }

        var parameters = [
            "client_id": clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        if !clientSecret.isEmpty {
            parameters["client_secret"] = clientSecret
        }

        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters.percentEncoded()

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.tokenExchangeFailed("Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AuthError.tokenExchangeFailed("Status \(httpResponse.statusCode): \(errorBody)")
            }

            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            // Keep the existing refresh token if not provided in response
            let newTokens = OAuthTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken ?? refreshToken,
                tokenType: tokenResponse.tokenType,
                expiresIn: tokenResponse.expiresIn,
                scope: tokenResponse.scope
            )

            try keychain.saveTokens(newTokens)
            self.tokens = newTokens

        } catch let authError as AuthError {
            throw authError
        } catch {
            throw AuthError.networkError(error)
        }
    }

    // MARK: - Sign In

    func signIn() async throws {
        guard isConfigured else {
            throw AuthError.configurationMissing
        }

        isLoading = true
        error = nil

        defer { isLoading = false }

        // Generate PKCE code verifier and challenge
        codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier!)

        #if os(macOS)
        try await signInMacOS(codeChallenge: codeChallenge)
        #elseif os(iOS)
        try await signInIOS(codeChallenge: codeChallenge)
        #endif

        await fetchUserInfo()
    }

    #if os(macOS)
    private func signInMacOS(codeChallenge: String) async throws {
        // Start local server to receive callback
        let server = CallbackServer(port: redirectPort)
        callbackServer = server

        do {
            try server.start()
        } catch {
            throw AuthError.serverError("Could not start callback server: \(error.localizedDescription)")
        }

        // Build authorization URL
        var components = URLComponents(string: authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else {
            server.stop()
            throw AuthError.invalidURL
        }

        // Open browser for authentication
        NSWorkspace.shared.open(authURL)

        // Wait for callback
        let code: String
        do {
            code = try await server.waitForCode(timeout: 120)
        } catch {
            server.stop()
            throw AuthError.authenticationFailed("Timed out or cancelled")
        }

        server.stop()
        callbackServer = nil

        // Exchange code for tokens
        try await exchangeCodeForTokens(code)
    }
    #endif

    #if os(iOS)
    private func signInIOS(codeChallenge: String) async throws {
        // Build authorization URL
        var components = URLComponents(string: authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else {
            throw AuthError.invalidURL
        }

        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: Self.iOSCallbackScheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: AuthError.authenticationFailed(error.localizedDescription))
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.authenticationFailed("No authorization code received"))
                    return
                }

                continuation.resume(returning: code)
            }

            let contextProvider = ASWebAuthPresentationContext()
            session.presentationContextProvider = contextProvider
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        // Exchange code for tokens
        try await exchangeCodeForTokens(code)
    }
    #endif

    private func exchangeCodeForTokens(_ code: String) async throws {
        guard let verifier = codeVerifier else {
            throw AuthError.authenticationFailed("Missing code verifier")
        }

        var parameters = [
            "client_id": clientId,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]

        if !clientSecret.isEmpty {
            parameters["client_secret"] = clientSecret
        }

        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters.percentEncoded()

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.tokenExchangeFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthError.tokenExchangeFailed("Status \(httpResponse.statusCode): \(errorBody)")
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let tokens = tokenResponse.toOAuthTokens()

        try keychain.saveTokens(tokens)
        self.tokens = tokens
        isAuthenticated = true
        codeVerifier = nil
    }

    private func fetchUserInfo() async {
        guard let tokens = tokens else { return }

        var request = URLRequest(url: URL(string: userInfoEndpoint)!)
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let email = json["email"] as? String {
                    userEmail = email
                }
                if let name = json["name"] as? String {
                    userName = name
                }
            }
        } catch {
            // User info fetch failed silently - non-critical
        }
    }

    // MARK: - Sign Out

    func signOut() {
        try? keychain.deleteTokens()
        tokens = nil
        isAuthenticated = false
        userEmail = nil
        userName = nil
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .prefix(128)
            .description
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - iOS ASWebAuthenticationSession Context

#if os(iOS)
class ASWebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if !EXTENSION
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            return window
        }
        #endif
        return ASPresentationAnchor()
    }
}
#endif

// MARK: - Local Callback Server (macOS only)

#if os(macOS)
import Network

class CallbackServer {
    private var listener: NWListener?
    private let port: UInt16
    private var codeContinuation: CheckedContinuation<String, Error>?

    init(port: UInt16) {
        self.port = port
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    func waitForCode(timeout: TimeInterval) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.codeContinuation = continuation

            // Set timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                if let cont = self?.codeContinuation {
                    self?.codeContinuation = nil
                    cont.resume(throwing: AuthError.authenticationFailed("Timeout"))
                }
            }
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let data = data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            // Parse the request to get the authorization code
            if let code = self?.extractCode(from: request) {
                // Send success response
                let response = """
                HTTP/1.1 200 OK\r
                Content-Type: text/html\r
                Connection: close\r
                \r
                <html><body><h1>Success!</h1><p>You can close this window and return to Pigeon Mail.</p><script>window.close();</script></body></html>
                """

                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })

                // Resume continuation with code
                if let cont = self?.codeContinuation {
                    self?.codeContinuation = nil
                    cont.resume(returning: code)
                }
            } else if request.contains("error=") {
                // Handle error
                let errorResponse = """
                HTTP/1.1 200 OK\r
                Content-Type: text/html\r
                Connection: close\r
                \r
                <html><body><h1>Authentication Failed</h1><p>Please try again.</p></body></html>
                """

                connection.send(content: errorResponse.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })

                if let cont = self?.codeContinuation {
                    self?.codeContinuation = nil
                    cont.resume(throwing: AuthError.authenticationFailed("User denied access"))
                }
            } else {
                connection.cancel()
            }
        }
    }

    private func extractCode(from request: String) -> String? {
        // Parse HTTP request to extract code parameter
        // Request looks like: GET /?code=xxx&scope=... HTTP/1.1
        guard let urlLine = request.split(separator: "\r\n").first,
              let urlPart = urlLine.split(separator: " ").dropFirst().first,
              let components = URLComponents(string: "http://localhost\(urlPart)"),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return nil
        }
        return code
    }
}
#endif

// MARK: - Dictionary Extension

extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data? {
        map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}
