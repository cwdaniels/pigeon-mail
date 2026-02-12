import SwiftUI

struct FavoritesBarView: View {
    @StateObject private var favoritesManager = FavoritesManager.shared
    let onSelectFavorite: (FavoriteContact) -> Void

    var body: some View {
        let topFavorites = favoritesManager.getTopFavorites(limit: 5)

        if !topFavorites.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(topFavorites) { favorite in
                        FavoriteChip(favorite: favorite) {
                            onSelectFavorite(favorite)
                        } onTogglePin: {
                            favoritesManager.togglePin(email: favorite.email)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            .background(Color.platformControlBackground.opacity(0.5))
        }
    }
}

struct FavoriteChip: View {
    let favorite: FavoriteContact
    let onSelect: () -> Void
    let onTogglePin: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 4) {
                if favorite.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                Text(favorite.displayName)
                    .font(.callout)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.15))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onTogglePin()
            } label: {
                if favorite.isPinned {
                    Label("Unpin", systemImage: "pin.slash")
                } else {
                    Label("Pin to Favorites", systemImage: "pin")
                }
            }

            Button(role: .destructive) {
                FavoritesManager.shared.removeFavorite(email: favorite.email)
            } label: {
                Label("Remove from Favorites", systemImage: "trash")
            }
        }
    }
}

#Preview {
    FavoritesBarView { favorite in
        print("Selected: \(favorite.email)")
    }
}
