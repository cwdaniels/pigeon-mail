import Foundation

struct Contact: Identifiable, Hashable {
    let id: String
    let name: String
    let email: String
    let photoURL: URL?

    init(id: String = UUID().uuidString, name: String, email: String, photoURL: URL? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.photoURL = photoURL
    }

    var displayName: String {
        name.isEmpty ? email : name
    }

    var displayString: String {
        if name.isEmpty {
            return email
        }
        return "\(name) <\(email)>"
    }

    func matches(_ query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        return name.lowercased().contains(lowercasedQuery) ||
               email.lowercased().contains(lowercasedQuery)
    }

    /// Returns a match score for ranking search results
    /// - 4: Exact match (name or email equals query)
    /// - 3: Prefix match (name or email starts with query)
    /// - 2: Word boundary match (query matches start of a word)
    /// - 1: Substring match (contains query)
    /// - 0: No match
    func matchScore(for query: String) -> Int {
        let lowercasedQuery = query.lowercased()
        let lowercasedName = name.lowercased()
        let lowercasedEmail = email.lowercased()

        // Exact match
        if lowercasedName == lowercasedQuery || lowercasedEmail == lowercasedQuery {
            return 4
        }

        // Prefix match
        if lowercasedName.hasPrefix(lowercasedQuery) || lowercasedEmail.hasPrefix(lowercasedQuery) {
            return 3
        }

        // Word boundary match
        if matchesWordBoundary(lowercasedQuery, in: lowercasedName) ||
           matchesWordBoundary(lowercasedQuery, in: lowercasedEmail) {
            return 2
        }

        // Substring match
        if lowercasedName.contains(lowercasedQuery) || lowercasedEmail.contains(lowercasedQuery) {
            return 1
        }

        return 0
    }

    /// Checks if query matches the start of any word in the text
    /// "Jo" matches "John" but not "banjo"
    private func matchesWordBoundary(_ query: String, in text: String) -> Bool {
        // Split by common word separators
        let separators = CharacterSet.alphanumerics.inverted
        let words = text.components(separatedBy: separators).filter { !$0.isEmpty }

        for word in words {
            if word.hasPrefix(query) {
                return true
            }
        }
        return false
    }
}

// MARK: - Google People API Response Models

struct PeopleResponse: Codable {
    let connections: [Person]?
    let otherContacts: [Person]?
    let nextPageToken: String?
    let totalPeople: Int?
    let totalItems: Int?
}

struct Person: Codable {
    let resourceName: String?
    let etag: String?
    let names: [Name]?
    let emailAddresses: [EmailAddress]?
    let photos: [Photo]?

    func toContacts() -> [Contact] {
        guard let emails = emailAddresses else { return [] }

        let displayName = names?.first?.displayName ?? ""
        let photoURL = photos?.first?.url.flatMap { URL(string: $0) }

        return emails.compactMap { emailAddr in
            guard let email = emailAddr.value, !email.isEmpty else { return nil }
            return Contact(
                id: resourceName ?? UUID().uuidString,
                name: displayName,
                email: email,
                photoURL: photoURL
            )
        }
    }
}

struct Name: Codable {
    let displayName: String?
    let familyName: String?
    let givenName: String?
}

struct EmailAddress: Codable {
    let value: String?
    let type: String?
}

struct Photo: Codable {
    let url: String?
}

// MARK: - Google Directory Search Response

struct DirectorySearchResponse: Codable {
    let people: [Person]?
    let nextPageToken: String?
    let totalSize: Int?
}
