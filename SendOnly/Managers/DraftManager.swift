import Foundation
import Combine

/// Represents a draft with display information
struct DraftSummary: Identifiable {
    let id: String
    let messageId: String?
    let to: String
    let subject: String
    let snippet: String
    let updatedAt: Date?
}

@MainActor
final class DraftManager: ObservableObject {
    static let shared = DraftManager()

    @Published private(set) var currentDraftId: String?
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var drafts: [DraftSummary] = []
    @Published private(set) var isLoadingDrafts = false

    private let gmailService = GmailService.shared
    private var syncTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    private let debounceInterval: TimeInterval = 3.0 // Seconds to wait before syncing

    private init() {}

    // MARK: - Auto-Save Draft

    /// Call this when email content changes to trigger auto-save
    func emailDidChange(_ email: Email) {
        // Cancel any pending debounce
        debounceTask?.cancel()

        // Don't sync empty emails
        guard !email.isEmpty else {
            return
        }

        // Debounce the sync
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
                await syncDraft(email)
            } catch {
                // Task was cancelled, which is expected
            }
        }
    }

    /// Immediately sync the current draft
    func syncDraft(_ email: Email) async {
        guard !email.isEmpty else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            if let draftId = currentDraftId {
                // Update existing draft
                let response = try await gmailService.updateDraft(draftId: draftId, email: email)
                currentDraftId = response.id
            } else {
                // Create new draft
                let response = try await gmailService.createDraft(email)
                currentDraftId = response.id
            }
            lastSyncTime = Date()
        } catch {
            print("Failed to sync draft: \(error)")
            // Don't throw - draft sync failures shouldn't block the user
        }
    }

    // MARK: - Delete Draft

    /// Delete the current draft from Gmail
    func deleteDraft() async {
        guard let draftId = currentDraftId else { return }

        do {
            try await gmailService.deleteDraft(draftId: draftId)
            currentDraftId = nil
        } catch {
            print("Failed to delete draft: \(error)")
        }
    }

    /// Delete draft after successful send
    func onEmailSent() async {
        await deleteDraft()
    }

    // MARK: - Clear State

    func clearDraft() {
        debounceTask?.cancel()
        syncTask?.cancel()
        currentDraftId = nil
        lastSyncTime = nil
    }

    // MARK: - Draft Status

    var syncStatusText: String {
        if isSyncing {
            return "Saving..."
        } else if let lastSync = lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Saved \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return ""
        }
    }

    // MARK: - Fetch Drafts

    /// Fetch all drafts from Gmail
    func fetchDrafts() async {
        isLoadingDrafts = true
        defer { isLoadingDrafts = false }

        do {
            let draftList = try await gmailService.listDrafts()

            // Fetch details for each draft to get subject/recipients
            var summaries: [DraftSummary] = []
            for item in draftList.prefix(10) { // Limit to 10 for performance
                do {
                    let detail = try await gmailService.getDraft(draftId: item.id)
                    let email = detail.toEmail()

                    let summary = DraftSummary(
                        id: detail.id,
                        messageId: detail.message?.id,
                        to: email.to.first ?? "(No recipient)",
                        subject: email.subject.isEmpty ? "(No subject)" : email.subject,
                        snippet: String(email.body.prefix(50)),
                        updatedAt: nil
                    )
                    summaries.append(summary)
                } catch {
                    print("Failed to fetch draft \(item.id): \(error)")
                }
            }

            drafts = summaries
        } catch {
            print("Failed to fetch drafts: \(error)")
            drafts = []
        }
    }

    /// Load a specific draft into the compose view
    func loadDraft(_ draftId: String) async -> Email? {
        do {
            let detail = try await gmailService.getDraft(draftId: draftId)
            currentDraftId = draftId
            lastSyncTime = Date()
            return detail.toEmail()
        } catch {
            print("Failed to load draft: \(error)")
            return nil
        }
    }

    /// Start editing an existing draft (sets the current draft ID)
    func startEditingDraft(_ draftId: String) {
        currentDraftId = draftId
    }
}
