#if os(macOS)
import Foundation
import SwiftUI
import AppKit

/// Manages the app's visibility mode (menu bar, dock, or both)
@MainActor
class AppModeManager: ObservableObject {
    static let shared = AppModeManager()

    @AppStorage("appMode") var appMode: String = "menuBar"

    private init() {}

    /// Apply the specified app mode
    /// - Parameter mode: "menuBar" (accessory), "dock" (regular), or "both" (regular)
    func applyMode(_ mode: String) {
        // Defer to next run loop to ensure NSApp is initialized
        DispatchQueue.main.async {
            guard let app = NSApp else { return }
            switch mode {
            case "dock", "both":
                // .regular: Shows in dock and can have menu bar
                app.setActivationPolicy(.regular)
            default:
                // .accessory: Menu bar only, hidden from dock
                app.setActivationPolicy(.accessory)
            }
        }
    }

    /// Apply the current stored mode
    func applyCurrentMode() {
        applyMode(appMode)
    }
}
#endif
