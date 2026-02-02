import SwiftUI
import SwiftData
import Combine

@main
struct PigeonMailApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var emailManager = EmailManager.shared
    @StateObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineQueueManager = OfflineQueueManager.shared

    @AppStorage("menuBarIcon") private var menuBarIcon: String = "pigeon"

    // Timer for processing scheduled emails every 60 seconds
    private let scheduledEmailTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ScheduledEmail.self,
            QueuedEmail.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(authService)
                .environmentObject(emailManager)
                .environmentObject(offlineQueueManager)
                .environmentObject(networkMonitor)
                .modelContainer(sharedModelContainer)
                .onReceive(scheduledEmailTimer) { _ in
                    processScheduledEmails()
                }
        } label: {
            // Use custom pigeon icon or mail icon based on settings
            if menuBarIcon == "pigeon" {
                Image(systemName: "bird.fill")
            } else {
                Image(systemName: "envelope.fill")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(authService)
        }

        // Compose window that can be opened via hotkey
        Window("Compose Email", id: "compose") {
            ComposeView()
                .environmentObject(authService)
                .environmentObject(emailManager)
                .modelContainer(sharedModelContainer)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 500)
        .keyboardShortcut("m", modifiers: [.command, .option, .shift])
    }

    init() {
        // Register global hotkey on app launch
        HotkeyManager.shared.registerGlobalHotkey()

        // Configure OfflineQueueManager with model context
        let container = sharedModelContainer
        OfflineQueueManager.shared.configure(modelContext: container.mainContext)

        // Process overdue scheduled emails on launch (with 2s delay for initialization)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let context = container.mainContext
            await EmailManager.shared.processScheduledEmails(modelContext: context)
        }
    }

    @MainActor
    private func processScheduledEmails() {
        let context = sharedModelContainer.mainContext
        Task {
            await EmailManager.shared.processScheduledEmails(modelContext: context)
        }
    }
}
