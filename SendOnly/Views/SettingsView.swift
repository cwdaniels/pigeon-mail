import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var hotkeyManager = HotkeyManager.shared

    @AppStorage("undoDelay") private var undoDelay: Int = 10
    @AppStorage("defaultSignature") private var defaultSignature: String = ""
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("menuBarIcon") private var menuBarIcon: String = "pigeon"
    @AppStorage("playSendSound") private var playSendSound: Bool = true
    @AppStorage("sendSoundName") private var sendSoundName: String = "Blow"
    @AppStorage("appMode") private var appMode: String = "menuBar"

    @State private var clientId: String = ""
    @State private var clientSecret: String = ""

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            accountTab
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }

            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 450, height: 350)
        .onAppear {
            loadOAuthConfig()
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("App Mode") {
                Picker("Show Pigeon in", selection: $appMode) {
                    Text("Menu Bar Only").tag("menuBar")
                    Text("Dock Only").tag("dock")
                    Text("Both Menu Bar & Dock").tag("both")
                }
                .pickerStyle(.radioGroup)
                .onChange(of: appMode) { _, newValue in
                    applyAppMode(newValue)
                }

                Text("Changes take effect immediately")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Appearance") {
                Picker("Menu bar icon", selection: $menuBarIcon) {
                    HStack {
                        Image(systemName: "bird.fill")
                        Text("Pigeon")
                    }.tag("pigeon")
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Envelope")
                    }.tag("envelope")
                }
                .pickerStyle(.radioGroup)
                .disabled(appMode == "dock")
            }

            Section("Send Settings") {
                Picker("Undo send delay", selection: $undoDelay) {
                    Text("5 seconds").tag(5)
                    Text("10 seconds").tag(10)
                    Text("20 seconds").tag(20)
                    Text("30 seconds").tag(30)
                }
                .pickerStyle(.menu)

                Toggle("Play sound when email sends", isOn: $playSendSound)

                if playSendSound {
                    HStack {
                        Picker("Sound", selection: $sendSoundName) {
                            ForEach(HotkeyManager.availableSounds, id: \.self) { sound in
                                Text(sound).tag(sound)
                            }
                        }
                        .pickerStyle(.menu)

                        Button {
                            HotkeyManager.shared.previewSound(sendSoundName)
                        } label: {
                            Image(systemName: "speaker.wave.2")
                        }
                        .help("Preview sound")
                    }
                }
            }

            Section("Signature") {
                TextEditor(text: $defaultSignature)
                    .frame(height: 80)
                    .font(.body)

                Text("This signature will be added to all new emails")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Startup") {
                Toggle("Launch Pigeon at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Account Tab

    private var accountTab: some View {
        Form {
            if authService.isAuthenticated {
                Section("Signed In") {
                    LabeledContent("Email", value: authService.userEmail ?? "Unknown")

                    Button("Sign Out") {
                        authService.signOut()
                    }
                    .foregroundColor(.red)
                }
            } else {
                Section("Sign In") {
                    Text("Not signed in")
                        .foregroundColor(.secondary)

                    Button("Sign in with Google") {
                        Task {
                            try? await authService.signIn()
                        }
                    }
                    .disabled(!authService.isConfigured)
                }
            }

            Section("OAuth Configuration") {
                TextField("Client ID", text: $clientId)
                    .textFieldStyle(.roundedBorder)

                SecureField("Client Secret (optional for PKCE)", text: $clientSecret)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save") {
                        authService.configure(clientId: clientId, clientSecret: clientSecret)
                    }
                    .disabled(clientId.isEmpty)

                    Spacer()

                    Link("Get credentials", destination: URL(string: "https://console.cloud.google.com/apis/credentials")!)
                }

                Text("Create OAuth 2.0 credentials in Google Cloud Console. Select 'Desktop app' as the application type.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Shortcuts Tab

    private var shortcutsTab: some View {
        Form {
            Section("Global Hotkey") {
                HStack {
                    Text("Open Compose Window")
                    Spacer()
                    Text(hotkeyManager.hotkeyDisplayString)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .font(.system(.body, design: .monospaced))
                }

                if !hotkeyManager.isHotkeyRegistered {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Hotkey not registered. The app may need accessibility permissions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button("Re-register Hotkey") {
                    hotkeyManager.registerGlobalHotkey()
                }

                if let error = hotkeyManager.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section("Keyboard Shortcuts") {
                shortcutRow("Send Email", shortcut: "⌘ Return")
                shortcutRow("Schedule Send", shortcut: "⌘⇧ Return")
                shortcutRow("Undo Send", shortcut: "⌘ Z")
                shortcutRow("Discard Draft", shortcut: "Escape")
                shortcutRow("New Message (in app)", shortcut: "⌘ N")
                shortcutRow("Settings", shortcut: "⌘ ,")
                shortcutRow("Quit", shortcut: "⌘ Q")
            }

            Section("Accessibility") {
                Text("To use global hotkeys, Pigeon Mail needs accessibility permissions.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Open System Settings") {
                    openAccessibilitySettings()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Helpers

    private func shortcutRow(_ action: String, shortcut: String) -> some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func loadOAuthConfig() {
        clientId = UserDefaults.standard.string(forKey: "oauth_client_id") ?? ""
        clientSecret = UserDefaults.standard.string(forKey: "oauth_client_secret") ?? ""
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        // Use SMAppService for modern launch at login (macOS 13+)
        // For now, we'll just store the preference
        // Full implementation would use ServiceManagement framework
        print("Launch at login: \(enabled)")
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService.shared)
}
