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
        switch mode {
        case "dock", "both":
            // .regular: Shows in dock and can have menu bar
            NSApp.setActivationPolicy(.regular)
        default:
            // .accessory: Menu bar only, hidden from dock
            NSApp.setActivationPolicy(.accessory)
        }
    }

    /// Apply the current stored mode
    func applyCurrentMode() {
        applyMode(appMode)
    }
}
