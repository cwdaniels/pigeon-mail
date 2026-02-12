#if os(iOS)
import SwiftUI

struct iOSSettingsView: View {
    @EnvironmentObject private var authService: AuthService

    @AppStorage("undoDelay") private var undoDelay: Int = 10
    @AppStorage("defaultSignature") private var defaultSignature: String = ""
    @AppStorage("playSendSound") private var playSendSound: Bool = true
    @AppStorage("showFavoritesBar") private var showFavoritesBar: Bool = true

    @State private var clientId: String = ""
    @State private var clientSecret: String = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            // Account
            Section("Account") {
                if authService.isAuthenticated {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(authService.userEmail ?? "Unknown")
                            .foregroundColor(.secondary)
                    }

                    if let name = authService.userName, !name.isEmpty {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(name)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button("Sign Out", role: .destructive) {
                        authService.signOut()
                    }
                } else {
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

            // Send Settings
            Section("Send Settings") {
                Picker("Undo send delay", selection: $undoDelay) {
                    Text("5 seconds").tag(5)
                    Text("10 seconds").tag(10)
                    Text("20 seconds").tag(20)
                    Text("30 seconds").tag(30)
                }

                Toggle("Play sound when email sends", isOn: $playSendSound)
            }

            // Signature
            Section("Signature") {
                TextEditor(text: $defaultSignature)
                    .frame(height: 80)

                Text("This signature will be added to all new emails")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Favorites
            Section("Favorites Bar") {
                Toggle("Show favorites bar in compose", isOn: $showFavoritesBar)

                Text("Quick access to your most-used email addresses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // OAuth Configuration
            Section("OAuth Configuration") {
                TextField("Client ID", text: $clientId)
                    .textContentType(.none)
                    .autocapitalization(.none)

                SecureField("Client Secret (optional for PKCE)", text: $clientSecret)

                Button("Save") {
                    authService.configure(clientId: clientId, clientSecret: clientSecret)
                }
                .disabled(clientId.isEmpty)

                Text("Create OAuth 2.0 credentials in Google Cloud Console. Select 'iOS' as the application type.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("2.1")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Built with")
                    Spacer()
                    Text("Claude Opus 4.6")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            clientId = UserDefaults.standard.string(forKey: "oauth_client_id") ?? ""
            clientSecret = UserDefaults.standard.string(forKey: "oauth_client_secret") ?? ""
        }
    }
}
#endif
