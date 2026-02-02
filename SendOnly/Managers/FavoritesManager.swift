import Foundation
import SwiftUI

/// A favorite contact with usage tracking and pin support
struct FavoriteContact: Identifiable, Codable, Equatable {
    let id: String
    var email: String
    var name: String
    var isPinned: Bool
    var usageCount: Int
    var lastUsed: Date

    init(email: String, name: String = "", isPinned: Bool = false, usageCount: Int = 1) {
        self.id = email.lowercased()
        self.email = email
        self.name = name
        self.isPinned = isPinned
        self.usageCount = usageCount
        self.lastUsed = Date()
    }

    var displayName: String {
        name.isEmpty ? email : name
    }
}

@MainActor
final class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()

    @AppStorage("showFavoritesBar") var showFavoritesBar: Bool = true
    @Published private(set) var favorites: [FavoriteContact] = []

    private let favoritesKey = "favoriteEmails"
    private let maxFavorites = 20

    private init() {
        loadFavorites()
    }

    // MARK: - Public API

    /// Record usage of an email address (call after successful send)
    func recordUsage(email: String, name: String = "") {
        let normalizedEmail = email.lowercased()

        if let index = favorites.firstIndex(where: { $0.id == normalizedEmail }) {
            // Update existing favorite
            favorites[index].usageCount += 1
            favorites[index].lastUsed = Date()
            if !name.isEmpty && favorites[index].name.isEmpty {
                favorites[index].name = name
            }
        } else {
            // Add new favorite
            let newFavorite = FavoriteContact(email: email, name: name)
            favorites.append(newFavorite)

            // Limit total favorites
            if favorites.count > maxFavorites {
                // Remove least used non-pinned favorites
                let unpinned = favorites.filter { !$0.isPinned }
                    .sorted { $0.usageCount < $1.usageCount }
                if let toRemove = unpinned.first {
                    favorites.removeAll { $0.id == toRemove.id }
                }
            }
        }

        saveFavorites()
    }

    /// Toggle pin status for a contact
    func togglePin(email: String) {
        let normalizedEmail = email.lowercased()
        if let index = favorites.firstIndex(where: { $0.id == normalizedEmail }) {
            favorites[index].isPinned.toggle()
            saveFavorites()
        }
    }

    /// Get top favorites for display (pinned first, then by usage)
    func getTopFavorites(limit: Int = 5) -> [FavoriteContact] {
        let sorted = favorites.sorted { lhs, rhs in
            // Pinned items first
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            // Then by usage count
            if lhs.usageCount != rhs.usageCount {
                return lhs.usageCount > rhs.usageCount
            }
            // Then by last used
            return lhs.lastUsed > rhs.lastUsed
        }
        return Array(sorted.prefix(limit))
    }

    /// Remove a favorite
    func removeFavorite(email: String) {
        let normalizedEmail = email.lowercased()
        favorites.removeAll { $0.id == normalizedEmail }
        saveFavorites()
    }

    // MARK: - Persistence

    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let decoded = try? JSONDecoder().decode([FavoriteContact].self, from: data) else {
            favorites = []
            return
        }
        favorites = decoded
    }

    private func saveFavorites() {
        guard let encoded = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(encoded, forKey: favoritesKey)
    }
}
