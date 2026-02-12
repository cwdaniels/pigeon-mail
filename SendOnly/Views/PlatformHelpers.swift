import SwiftUI

extension Color {
    #if os(macOS)
    static let platformWindowBackground = Color(NSColor.windowBackgroundColor)
    static let platformControlBackground = Color(NSColor.controlBackgroundColor)
    static let platformTextBackground = Color(NSColor.textBackgroundColor)
    #elseif os(iOS)
    static let platformWindowBackground = Color(UIColor.systemBackground)
    static let platformControlBackground = Color(UIColor.secondarySystemBackground)
    static let platformTextBackground = Color(UIColor.systemBackground)
    #endif
}
