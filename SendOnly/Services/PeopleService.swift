import Foundation

enum PeopleError: Error, LocalizedError, RetryableError {
    case notAuthenticated
    case invalidResponse
    case apiError(Int, String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Google"
        case .invalidResponse:
            return "Invalid response from People API"
        case .apiError(let code, let message):
            return "People API error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError:
            return true
        case .apiError(let code, _):
            // Retry on 5xx server errors, not on 4xx client errors
            return code >= 500 && code < 600
        case .notAuthenticated, .invalidResponse:
            return false
        }
    }
}

actor PeopleService {
    static let shared = PeopleService()

    private let baseURL = "https://people.googleapis.com/v1"
    private var cachedContacts: [Contact] = []
    private var lastFetchTime: Date?
    private let cacheExpiry: TimeInterval = 300 // 5 minutes

    // Recently used emails storage
    private let recentEmailsKey = "recentEmails"
    private let maxRecentEmails = 50

    private init() {}

    // MARK: - Recent Emails

    func addRecentEmail(_ email: String, name: String? = nil) {
        var recentEmails = getRecentEmails()

        // Remove if already exists (to move to front)
        recentEmails.removeAll { $0["email"] == email }

        // Add to front
        let entry: [String: String] = [
            "email": email,
            "name": name ?? "",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        recentEmails.insert(entry, at: 0)

        // Limit size
        if recentEmails.count > maxRecentEmails {
            recentEmails = Array(recentEmails.prefix(maxRecentEmails))
        }

        UserDefaults.standard.set(recentEmails, forKey: recentEmailsKey)
    }

    func getRecentEmails() -> [[String: String]] {
        UserDefaults.standard.array(forKey: recentEmailsKey) as? [[String: String]] ?? []
    }

    func recentEmailContacts() -> [Contact] {
        getRecentEmails().compactMap { entry -> Contact? in
            guard let email = entry["email"], !email.isEmpty else { return nil }
            let name = entry["name"]?.isEmpty == false ? entry["name"]! : ""
            return Contact(
                id: "recent_\(email)",
                name: name,
                email: email,
                photoURL: nil
            )
        }
    }

    // MARK: - Fetch Contacts

    func fetchContacts(forceRefresh: Bool = false) async throws -> [Contact] {
        // Return cached if valid
        if !forceRefresh,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheExpiry,
           !cachedContacts.isEmpty {
            return cachedContacts
        }

        let token = try await AuthService.shared.getAccessToken()

        var allContacts: [Contact] = []

        // Fetch from connections (main contacts)
        let connections = try await fetchConnections(token: token)
        allContacts.append(contentsOf: connections)

        // Fetch from other contacts (frequent/suggested)
        let otherContacts = try await fetchOtherContacts(token: token)
        allContacts.append(contentsOf: otherContacts)

        // Deduplicate by email
        var seenEmails = Set<String>()
        cachedContacts = allContacts.filter { contact in
            let email = contact.email.lowercased()
            if seenEmails.contains(email) {
                return false
            }
            seenEmails.insert(email)
            return true
        }

        lastFetchTime = Date()
        return cachedContacts
    }

    private func fetchConnections(token: String) async throws -> [Contact] {
        try await withRetry {
            try await self.performFetchConnections(token: token)
        }
    }

    private func performFetchConnections(token: String) async throws -> [Contact] {
        var components = URLComponents(string: "\(baseURL)/people/me/connections")!
        components.queryItems = [
            URLQueryItem(name: "personFields", value: "names,emailAddresses,photos"),
            URLQueryItem(name: "pageSize", value: "1000"),
            URLQueryItem(name: "sortOrder", value: "LAST_MODIFIED_DESCENDING")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PeopleError.invalidResponse
            }

            // 200 OK with empty connections is valid
            guard httpResponse.statusCode == 200 else {
                let errorMessage = parseErrorMessage(from: data)
                throw PeopleError.apiError(httpResponse.statusCode, errorMessage)
            }

            let peopleResponse = try JSONDecoder().decode(PeopleResponse.self, from: data)
            return peopleResponse.connections?.flatMap { $0.toContacts() } ?? []
        } catch let error as PeopleError {
            throw error
        } catch {
            throw PeopleError.networkError(error)
        }
    }

    private func fetchOtherContacts(token: String) async throws -> [Contact] {
        try await withRetry {
            try await self.performFetchOtherContacts(token: token)
        }
    }

    private func performFetchOtherContacts(token: String) async throws -> [Contact] {
        var components = URLComponents(string: "\(baseURL)/otherContacts")!
        components.queryItems = [
            URLQueryItem(name: "readMask", value: "names,emailAddresses,photos"),
            URLQueryItem(name: "pageSize", value: "1000")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PeopleError.invalidResponse
            }

            // Other contacts may not exist - 200 with empty is fine
            guard httpResponse.statusCode == 200 else {
                // Don't fail on other contacts error, just return empty
                return []
            }

            let peopleResponse = try JSONDecoder().decode(PeopleResponse.self, from: data)
            return peopleResponse.otherContacts?.flatMap { $0.toContacts() } ?? []
        } catch let error as PeopleError {
            throw error
        } catch {
            throw PeopleError.networkError(error)
        }
    }

    // MARK: - Search Directory (Google Workspace)

    private func searchDirectoryPeople(query: String, token: String) async -> [Contact] {
        guard query.count >= 2 else { return [] } // Directory search requires at least 2 chars

        var components = URLComponents(string: "\(baseURL)/people:searchDirectoryPeople")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "readMask", value: "names,emailAddresses,photos"),
            URLQueryItem(name: "pageSize", value: "30"),
            URLQueryItem(name: "sources", value: "DIRECTORY_SOURCE_TYPE_DOMAIN_PROFILE")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                // Directory search may not be available for all accounts
                return []
            }

            let directoryResponse = try JSONDecoder().decode(DirectorySearchResponse.self, from: data)
            return directoryResponse.people?.flatMap { $0.toContacts() } ?? []
        } catch {
            // Silently fail - directory may not be available
            return []
        }
    }

    // MARK: - Search Contacts

    func searchContacts(query: String) async -> [Contact] {
        // Get recent emails as a set for quick lookup
        let recentEmails = Set(recentEmailContacts().map { $0.email.lowercased() })
        let recentContacts = recentEmailContacts()

        // Ensure contacts are loaded
        let contacts = (try? await fetchContacts()) ?? cachedContacts

        guard !query.isEmpty else {
            // Return recent emails first, then contacts
            let recentFiltered = recentContacts.prefix(5)
            let remaining = contacts.filter { contact in
                !recentEmails.contains(contact.email.lowercased())
            }.prefix(5)
            return Array(recentFiltered) + Array(remaining)
        }

        // Also search the organization directory (for Google Workspace accounts)
        var directoryContacts: [Contact] = []
        if let token = try? await AuthService.shared.getAccessToken() {
            directoryContacts = await searchDirectoryPeople(query: query, token: token)
        }

        // Combine all contacts, deduplicating by email
        var seenEmails = Set<String>()
        var allContacts: [Contact] = []

        // Add recent contacts first
        for contact in recentContacts {
            let email = contact.email.lowercased()
            if !seenEmails.contains(email) {
                seenEmails.insert(email)
                allContacts.append(contact)
            }
        }

        // Add directory results (high priority for workspace users)
        for contact in directoryContacts {
            let email = contact.email.lowercased()
            if !seenEmails.contains(email) {
                seenEmails.insert(email)
                allContacts.append(contact)
            }
        }

        // Add personal contacts
        for contact in contacts {
            let email = contact.email.lowercased()
            if !seenEmails.contains(email) {
                seenEmails.insert(email)
                allContacts.append(contact)
            }
        }

        // Score and filter contacts
        let scoredContacts: [(contact: Contact, score: Int)] = allContacts.compactMap { contact in
            let baseScore = contact.matchScore(for: query)
            guard baseScore > 0 else { return nil }

            // Add +10 boost for recent contacts
            let isRecent = recentEmails.contains(contact.email.lowercased())
            // Add +5 boost for directory results (they matched the server-side search)
            let isFromDirectory = directoryContacts.contains { $0.email.lowercased() == contact.email.lowercased() }
            let finalScore = baseScore + (isRecent ? 10 : 0) + (isFromDirectory ? 5 : 0)

            return (contact, finalScore)
        }

        // Sort by score descending, then alphabetically by displayName
        let sorted = scoredContacts.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.contact.displayName.lowercased() < rhs.contact.displayName.lowercased()
        }

        // Return top 10 results
        return Array(sorted.prefix(10).map { $0.contact })
    }

    // MARK: - Cache Management

    func clearCache() {
        cachedContacts = []
        lastFetchTime = nil
    }

    // MARK: - Helpers

    private func parseErrorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}
