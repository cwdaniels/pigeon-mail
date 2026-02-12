#if os(iOS)
import SwiftUI
import SwiftData

struct iOSMainView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var emailManager: EmailManager
    @EnvironmentObject private var offlineQueueManager: OfflineQueueManager
    @EnvironmentObject private var networkMonitor: NetworkMonitor

    @StateObject private var draftManager = DraftManager.shared

    @State private var showCompose = false
    @State private var showSettings = false

    // Sent mail state
    @State private var recentSent: [SentSummary] = []
    @State private var isLoadingSent = false
    @State private var pigeonsSentToday: Int = 0
    @State private var showAllSent = false
    @State private var allSent: [SentSummary] = []
    @State private var isLoadingAllSent = false

    @Query(sort: \ScheduledEmail.scheduledDate)
    private var allScheduledEmails: [ScheduledEmail]

    @Query(sort: \QueuedEmail.queuedAt)
    private var allQueuedEmails: [QueuedEmail]

    @Environment(\.modelContext) private var modelContext

    private var scheduledEmails: [ScheduledEmail] {
        allScheduledEmails.filter { $0.status == .pending }
    }

    private var queuedEmails: [QueuedEmail] {
        allQueuedEmails.filter { $0.status == .pending || $0.status == .failed }
    }

    var body: some View {
        NavigationStack {
            if authService.isAuthenticated {
                authenticatedView
            } else {
                signInView
            }
        }
        .sheet(isPresented: $showCompose) {
            iOSComposeView()
                .environmentObject(authService)
                .environmentObject(emailManager)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                iOSSettingsView()
                    .environmentObject(authService)
            }
        }
        .sheet(isPresented: $showAllSent) {
            NavigationStack {
                iOSAllSentView(sentEmails: allSent, isLoading: isLoadingAllSent)
            }
        }
    }

    // MARK: - Authenticated View

    private var authenticatedView: some View {
        List {
            // Pigeon stats
            Section {
                HStack {
                    Image(systemName: "bird.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                    if pigeonsSentToday == 0 {
                        Text("No pigeons sent yet today")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(pigeonsSentToday) pigeon\(pigeonsSentToday == 1 ? "" : "s") delivered today")
                            .font(.callout)
                    }
                    Spacer()
                }
            }

            // Undo status
            if case .pendingUndo(let seconds) = emailManager.sendState {
                Section {
                    HStack {
                        Image(systemName: "paperplane.circle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sending to \(emailManager.pendingEmailRecipient ?? "recipient")...")
                                .font(.callout)
                            Text("\(seconds)s remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Undo") {
                            emailManager.cancelSend()
                            showCompose = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                    }
                }
            }

            if emailManager.sendState == .sent {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Email sent!")
                            .font(.callout)
                    }
                }
            }

            if emailManager.sendState == .queued {
                Section {
                    HStack {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .foregroundColor(.orange)
                        Text("Email queued for later")
                            .font(.callout)
                    }
                }
            }

            // Queued emails (offline)
            if !queuedEmails.isEmpty {
                Section("Queued (Offline)") {
                    ForEach(queuedEmails.prefix(10)) { queued in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(queued.displayRecipient)
                                    .lineLimit(1)
                                Text(queued.subject.isEmpty ? "(No subject)" : queued.subject)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if queued.status == .failed {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                offlineQueueManager.deleteQueuedEmail(queued)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    if networkMonitor.isConnected {
                        Button {
                            Task {
                                await offlineQueueManager.processAllPending()
                            }
                        } label: {
                            Label("Retry All", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }

            // Drafts section
            Section("Drafts") {
                if draftManager.isLoadingDrafts {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading drafts...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if draftManager.drafts.isEmpty {
                    Text("No drafts")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(draftManager.drafts.prefix(10)) { draft in
                        Button {
                            loadDraft(draft.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft.to)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                Text(draft.subject)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteDraft(draft)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            // Recently sent section
            Section("Recently Sent") {
                if isLoadingSent {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if recentSent.isEmpty {
                    Text("No sent emails")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(recentSent.prefix(5)) { sent in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sent.to)
                                .lineLimit(1)
                            Text(sent.subject)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Button {
                        showAllSent = true
                        Task { await fetchAllSent() }
                    } label: {
                        Label("See more...", systemImage: "chevron.right")
                            .font(.callout)
                    }
                }
            }

            // Scheduled emails
            if !scheduledEmails.isEmpty {
                Section("Scheduled") {
                    ForEach(scheduledEmails.prefix(10)) { scheduled in
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
                                scheduled.status = .cancelled
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Pigeon Mail")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCompose = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .refreshable {
            await draftManager.fetchDrafts()
            await fetchSentMail()
        }
        .task {
            if draftManager.drafts.isEmpty {
                await draftManager.fetchDrafts()
            }
            await fetchSentMail()
        }
        .onAppear {
            showCompose = true
        }
    }

    // MARK: - Sign In View

    private var signInView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bird.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Pigeon Mail")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Sign in with Google to start sending emails")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if !authService.isConfigured {
                Text("OAuth not configured. Add credentials.json or configure in Settings.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
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
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .disabled(!authService.isConfigured || authService.isLoading)

            if authService.isLoading {
                ProgressView()
            }

            if let error = authService.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button("Settings") {
                showSettings = true
            }
            .foregroundColor(.accentColor)
            .padding(.bottom, 20)
        }
        .navigationTitle("Welcome")
    }

    // MARK: - Actions

    private func loadDraft(_ draftId: String) {
        Task {
            if let email = await draftManager.loadDraft(draftId) {
                emailManager.currentEmail = email
                showCompose = true
            }
        }
    }

    private func deleteDraft(_ draft: DraftSummary) {
        Task {
            await draftManager.deleteDraftById(draft.id)
        }
    }

    private func fetchSentMail() async {
        isLoadingSent = true
        defer { isLoadingSent = false }

        do {
            let messages = try await GmailService.shared.listSentMessages(maxResults: 5)
            var summaries: [SentSummary] = []
            for item in messages {
                do {
                    let metadata = try await GmailService.shared.getMessage(messageId: item.id)
                    summaries.append(metadata.toSentSummary())
                } catch {
                    print("Failed to fetch sent message \(item.id): \(error)")
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

    private func fetchAllSent() async {
        isLoadingAllSent = true
        defer { isLoadingAllSent = false }

        do {
            let messages = try await GmailService.shared.listSentMessages(maxResults: 20)
            var summaries: [SentSummary] = []
            for item in messages {
                do {
                    let metadata = try await GmailService.shared.getMessage(messageId: item.id)
                    summaries.append(metadata.toSentSummary())
                } catch {
                    print("Failed to fetch sent message \(item.id): \(error)")
                }
            }
            allSent = summaries
        } catch {
            print("Failed to fetch all sent messages: \(error)")
        }
    }
}

// MARK: - All Sent View

struct iOSAllSentView: View {
    let sentEmails: [SentSummary]
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading sent emails...")
                        .foregroundColor(.secondary)
                }
            } else if sentEmails.isEmpty {
                Text("No sent emails")
                    .foregroundColor(.secondary)
            } else {
                ForEach(sentEmails) { sent in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sent.to)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(sent.subject)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        if let date = sent.date {
                            Text(date, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Sent Emails")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
#endif
