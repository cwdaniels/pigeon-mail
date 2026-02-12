#if os(macOS)
import SwiftUI
import SwiftData

struct MenuBarView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var emailManager: EmailManager
    @EnvironmentObject private var offlineQueueManager: OfflineQueueManager
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @StateObject private var draftManager = DraftManager.shared

    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ScheduledEmail.scheduledDate)
    private var allScheduledEmails: [ScheduledEmail]

    @Query(sort: \QueuedEmail.queuedAt)
    private var allQueuedEmails: [QueuedEmail]

    // Sent mail state
    @State private var recentSent: [SentSummary] = []
    @State private var pigeonsSentToday: Int = 0

    private var scheduledEmails: [ScheduledEmail] {
        allScheduledEmails.filter { $0.status == .pending }
    }

    private var queuedEmails: [QueuedEmail] {
        allQueuedEmails.filter { $0.status == .pending || $0.status == .failed }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if authService.isAuthenticated {
                authenticatedView
            } else {
                unauthenticatedView
            }
        }
        .frame(width: 280)
        .onReceive(NotificationCenter.default.publisher(for: .openComposeWindow)) { _ in
            openComposeWindow()
        }
    }

    // MARK: - Authenticated View

    private var authenticatedView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User info header
            HStack {
                Image(systemName: "bird.fill")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading) {
                    Text("Pigeon")
                        .fontWeight(.semibold)
                    if let email = authService.userEmail {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding()

            // Pigeon stats
            HStack(spacing: 6) {
                Image(systemName: "bird.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                if pigeonsSentToday == 0 {
                    Text("No pigeons sent yet today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(pigeonsSentToday) pigeon\(pigeonsSentToday == 1 ? "" : "s") delivered today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            Divider()

            // Compose button
            Button {
                openComposeWindow()
            } label: {
                Label("New Message", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuButtonStyle())
            .keyboardShortcut("n", modifiers: .command)

            // Pending send with undo
            if case .pendingUndo(let seconds) = emailManager.sendState {
                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Image(systemName: "paperplane.circle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sending to \(emailManager.pendingEmailRecipient ?? "recipient")...")
                            .font(.callout)
                            .lineLimit(1)
                        Text("\(seconds)s remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Undo") {
                        emailManager.cancelSend()
                        openComposeWindow()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                    .keyboardShortcut("z", modifiers: .command)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }

            // Sent confirmation
            if emailManager.sendState == .sent {
                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Email sent!")
                        .font(.callout)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Queued confirmation
            if emailManager.sendState == .queued {
                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .foregroundColor(.orange)
                    Text("Email queued for later")
                        .font(.callout)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Divider()
                .padding(.vertical, 4)

            // Queued emails section (offline)
            if !queuedEmails.isEmpty {
                HStack {
                    Text("Queued (Offline)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !networkMonitor.isConnected {
                        Image(systemName: "wifi.slash")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)

                ForEach(queuedEmails.prefix(5)) { queued in
                    queuedEmailRow(queued)
                }

                if queuedEmails.count > 5 {
                    Text("+ \(queuedEmails.count - 5) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }

                if networkMonitor.isConnected {
                    Button {
                        Task {
                            await offlineQueueManager.processAllPending()
                        }
                    } label: {
                        Label("Retry All", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(MenuButtonStyle())
                }

                Divider()
                    .padding(.vertical, 4)
            }

            // Drafts section
            draftsSection

            // Recently sent section
            sentSection

            // Scheduled emails section
            if !scheduledEmails.isEmpty {
                Text("Scheduled")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 4)

                ForEach(scheduledEmails.prefix(5)) { scheduled in
                    scheduledEmailRow(scheduled)
                }

                if scheduledEmails.count > 5 {
                    Text("+ \(scheduledEmails.count - 5) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }

                Divider()
                    .padding(.vertical, 4)
            }

            // Settings and sign out
            SettingsLink {
                Label("Settings...", systemImage: "gear")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuButtonStyle())
            .keyboardShortcut(",", modifiers: .command)

            Button {
                authService.signOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuButtonStyle())

            Divider()
                .padding(.vertical, 4)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Pigeon", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuButtonStyle())
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    // MARK: - Unauthenticated View

    private var unauthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bird.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Pigeon Mail")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Sign in with Google to start sending emails")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if !authService.isConfigured {
                Text("OAuth not configured. Add credentials.json or configure in Settings.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    do {
                        try await authService.signIn()
                    } catch {
                        authService.error = error as? AuthError ?? AuthError.authenticationFailed(error.localizedDescription)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "person.badge.key")
                    Text("Sign in with Google")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!authService.isConfigured || authService.isLoading)

            if authService.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }

            if let error = authService.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Divider()

            SettingsLink {
                Label("Settings...", systemImage: "gear")
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding()
    }

    // MARK: - Drafts Section

    private var draftsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Drafts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if draftManager.isLoadingDrafts {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    Button {
                        Task {
                            await draftManager.fetchDrafts()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh drafts")
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)

            if draftManager.drafts.isEmpty {
                Text("No drafts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            } else {
                ForEach(draftManager.drafts.prefix(5)) { draft in
                    draftRow(draft)
                }

                if draftManager.drafts.count > 5 {
                    Text("+ \(draftManager.drafts.count - 5) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }
            }

            Divider()
                .padding(.vertical, 4)
        }
        .onAppear {
            if draftManager.drafts.isEmpty {
                Task {
                    await draftManager.fetchDrafts()
                }
            }
        }
    }

    // MARK: - Sent Section

    private var sentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recently Sent")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 4)

            if recentSent.isEmpty {
                Text("No sent emails")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            } else {
                ForEach(recentSent.prefix(5)) { sent in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sent.to)
                                .lineLimit(1)
                            Text(sent.subject)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
            }

            Divider()
                .padding(.vertical, 4)
        }
        .task {
            await fetchSentMail()
        }
    }

    private func fetchSentMail() async {
        do {
            let messages = try await GmailService.shared.listSentMessages(maxResults: 5)
            var summaries: [SentSummary] = []
            for item in messages {
                if let metadata = try? await GmailService.shared.getMessage(messageId: item.id) {
                    summaries.append(metadata.toSentSummary())
                }
            }
            recentSent = summaries
        } catch {
            print("Failed to fetch sent messages: \(error)")
        }

        do {
            pigeonsSentToday = try await GmailService.shared.countTodaySentMessages()
        } catch {
            print("Failed to count today's sent: \(error)")
        }
    }

    private func draftRow(_ draft: DraftSummary) -> some View {
        Button {
            loadDraft(draft.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.to)
                        .lineLimit(1)
                    Text(draft.subject)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadDraft(_ draftId: String) {
        Task {
            if let email = await draftManager.loadDraft(draftId) {
                emailManager.currentEmail = email
                openComposeWindow()
            }
        }
    }

    // MARK: - Scheduled Email Row

    private func scheduledEmailRow(_ scheduled: ScheduledEmail) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(scheduled.to.first ?? "No recipient")
                    .lineLimit(1)
                Text(scheduled.subject.isEmpty ? "(No subject)" : scheduled.subject)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(scheduled.formattedScheduledDate)
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }
            Spacer()

            Button {
                cancelScheduledEmail(scheduled)
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Cancel scheduled email")
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Queued Email Row

    private func queuedEmailRow(_ queued: QueuedEmail) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(queued.displayRecipient)
                    .lineLimit(1)
                Text(queued.subject.isEmpty ? "(No subject)" : queued.subject)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if queued.status == .failed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    Text(queued.formattedQueuedDate)
                        .font(.caption2)
                        .foregroundColor(queued.status == .failed ? .orange : .secondary)
                    if queued.attemptCount > 0 {
                        Text("(\(queued.attemptCount) attempts)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()

            if networkMonitor.isConnected {
                Button {
                    Task {
                        await offlineQueueManager.retryEmail(queued)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Retry sending")
            }

            Button {
                offlineQueueManager.deleteQueuedEmail(queued)
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete queued email")
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func openComposeWindow() {
        openWindow(id: "compose")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func cancelScheduledEmail(_ scheduled: ScheduledEmail) {
        scheduled.status = .cancelled
    }
}

// MARK: - Menu Button Style

struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AuthService.shared)
        .environmentObject(EmailManager.shared)
        .modelContainer(for: ScheduledEmail.self, inMemory: true)
}
#endif
