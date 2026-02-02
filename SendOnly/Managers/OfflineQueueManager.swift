import Foundation
import SwiftData

@MainActor
final class OfflineQueueManager: ObservableObject {
    static let shared = OfflineQueueManager()

    @Published private(set) var isProcessing = false

    private var modelContext: ModelContext?
    private let gmailService = GmailService.shared
    private let networkMonitor = NetworkMonitor.shared
    private var networkObserver: Any?

    private let maxAttempts = 5

    private init() {
        setupNetworkObserver()
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Network Observer

    private func setupNetworkObserver() {
        networkObserver = NotificationCenter.default.addObserver(
            forName: .networkBecameAvailable,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.processAllPending()
            }
        }
    }

    deinit {
        if let observer = networkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Queue Management

    func queueEmail(_ email: Email, error: Error? = nil) {
        guard let modelContext = modelContext else {
            print("OfflineQueueManager: ModelContext not configured")
            return
        }

        let queuedEmail = QueuedEmail(email: email, error: error)
        modelContext.insert(queuedEmail)
        try? modelContext.save()

        // Post notification for UI update
        NotificationCenter.default.post(name: .emailQueued, object: queuedEmail)
    }

    func retryEmail(_ queuedEmail: QueuedEmail) async {
        guard networkMonitor.isConnected else {
            queuedEmail.lastError = "No network connection"
            try? modelContext?.save()
            return
        }

        queuedEmail.status = .sending
        queuedEmail.attemptCount += 1
        queuedEmail.lastAttemptAt = Date()

        do {
            let email = queuedEmail.toEmail()
            _ = try await gmailService.sendEmail(email)

            queuedEmail.status = .sent
            queuedEmail.lastError = nil
            try? modelContext?.save()

            // Notify success
            await NotificationManager.shared.sendNotification(
                title: "Queued Email Sent",
                body: "Email to \(email.to.first ?? "recipient") was sent successfully"
            )

            // Record recipients for autocomplete
            for recipient in email.to + email.cc + email.bcc {
                await PeopleService.shared.addRecentEmail(recipient)
            }
        } catch {
            queuedEmail.lastError = error.localizedDescription

            if queuedEmail.attemptCount >= maxAttempts {
                queuedEmail.status = .abandoned
            } else {
                queuedEmail.status = .failed
            }

            try? modelContext?.save()
        }
    }

    func processAllPending() async {
        guard let modelContext = modelContext else { return }
        guard networkMonitor.isConnected else { return }
        guard !isProcessing else { return }

        isProcessing = true
        defer { isProcessing = false }

        let pendingStatus = QueuedEmailStatus.pending
        let failedStatus = QueuedEmailStatus.failed
        let predicate = #Predicate<QueuedEmail> {
            $0.status == pendingStatus || $0.status == failedStatus
        }

        do {
            let descriptor = FetchDescriptor<QueuedEmail>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.queuedAt)]
            )
            let pendingEmails = try modelContext.fetch(descriptor)

            for queuedEmail in pendingEmails {
                await retryEmail(queuedEmail)
            }
        } catch {
            print("Error fetching pending emails: \(error)")
        }
    }

    func deleteQueuedEmail(_ queuedEmail: QueuedEmail) {
        modelContext?.delete(queuedEmail)
        try? modelContext?.save()
    }

    func abandonEmail(_ queuedEmail: QueuedEmail) {
        queuedEmail.status = .abandoned
        try? modelContext?.save()
    }

    // MARK: - Fetch Helpers

    func fetchPendingEmails() -> [QueuedEmail] {
        guard let modelContext = modelContext else { return [] }

        let pendingStatus = QueuedEmailStatus.pending
        let failedStatus = QueuedEmailStatus.failed
        let predicate = #Predicate<QueuedEmail> {
            $0.status == pendingStatus || $0.status == failedStatus
        }

        let descriptor = FetchDescriptor<QueuedEmail>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.queuedAt)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let emailQueued = Notification.Name("emailQueued")
}
