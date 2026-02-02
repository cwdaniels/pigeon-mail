import Foundation
import SwiftData

@MainActor
final class EmailManager: ObservableObject {
    static let shared = EmailManager()

    @Published var currentEmail = Email()
    @Published var sendState: EmailSendState = .idle
    @Published var error: Error?
    @Published private(set) var pendingEmailRecipient: String?

    private let gmailService = GmailService.shared
    private var undoTimer: Timer?
    private var pendingEmail: Email?
    private var undoCountdown: Int = 0

    var isPendingSend: Bool {
        if case .pendingUndo = sendState { return true }
        return false
    }

    // User preferences
    var undoDelay: Int {
        get { UserDefaults.standard.integer(forKey: "undoDelay").nonZero ?? 10 }
        set { UserDefaults.standard.set(newValue, forKey: "undoDelay") }
    }

    private init() {}

    // MARK: - Send Email

    func sendEmail() -> Bool {
        guard currentEmail.hasRecipients else {
            error = SendError.noRecipients
            return false
        }

        // Play send sound immediately when user hits send
        HotkeyManager.shared.playSendSound()

        // Start undo countdown
        pendingEmail = currentEmail
        pendingEmailRecipient = currentEmail.to.first ?? "recipient"
        undoCountdown = undoDelay
        sendState = .pendingUndo(secondsRemaining: undoCountdown)

        // Clear current email so compose window can close
        currentEmail = Email()

        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                self.undoCountdown -= 1

                if self.undoCountdown <= 0 {
                    timer.invalidate()
                    await self.actuallySendEmail()
                } else {
                    self.sendState = .pendingUndo(secondsRemaining: self.undoCountdown)
                }
            }
        }
        return true
    }

    func cancelSend() {
        undoTimer?.invalidate()
        undoTimer = nil

        if let email = pendingEmail {
            currentEmail = email
        }
        pendingEmail = nil
        pendingEmailRecipient = nil
        sendState = .cancelled

        // Reset to idle after a moment
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            sendState = .idle
        }
    }

    private func actuallySendEmail() async {
        guard let email = pendingEmail else {
            sendState = .idle
            pendingEmailRecipient = nil
            return
        }

        // Check network availability before attempting to send
        if !NetworkMonitor.shared.isConnected {
            OfflineQueueManager.shared.queueEmail(email)
            sendState = .queued
            pendingEmail = nil
            pendingEmailRecipient = nil

            // Reset to idle after showing queued state
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                sendState = .idle
            }
            return
        }

        sendState = .sending

        do {
            _ = try await gmailService.sendEmail(email)
            sendState = .sent
            pendingEmail = nil
            pendingEmailRecipient = nil

            // Record recipients for autocomplete
            Task {
                for recipient in email.to + email.cc + email.bcc {
                    await PeopleService.shared.addRecentEmail(recipient)
                }
            }

            // Reset to idle after showing success
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                sendState = .idle
            }
        } catch {
            // Check if this is a network error and queue if offline
            if !NetworkMonitor.shared.isConnected {
                OfflineQueueManager.shared.queueEmail(email, error: error)
                sendState = .queued
                pendingEmail = nil
                pendingEmailRecipient = nil

                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    sendState = .idle
                }
                return
            }

            self.error = error
            sendState = .failed(error)

            // Return email to compose view on failure
            currentEmail = email
            pendingEmail = nil
            pendingEmailRecipient = nil
        }
    }

    // MARK: - Schedule Email

    func scheduleEmail(for date: Date, modelContext: ModelContext) throws {
        guard currentEmail.hasRecipients else {
            throw SendError.noRecipients
        }

        guard date > Date() else {
            throw SendError.invalidScheduleDate
        }

        let scheduledEmail = ScheduledEmail(email: currentEmail, scheduledDate: date)
        modelContext.insert(scheduledEmail)
        try modelContext.save()

        currentEmail = Email() // Reset compose view
    }

    func cancelScheduledEmail(_ scheduledEmail: ScheduledEmail, modelContext: ModelContext) throws {
        scheduledEmail.status = .cancelled
        try modelContext.save()
    }

    func deleteScheduledEmail(_ scheduledEmail: ScheduledEmail, modelContext: ModelContext) throws {
        modelContext.delete(scheduledEmail)
        try modelContext.save()
    }

    // MARK: - Process Scheduled Emails

    func processScheduledEmails(modelContext: ModelContext) async {
        let now = Date()
        let pendingStatus = ScheduleStatus.pending
        let predicate = #Predicate<ScheduledEmail> {
            $0.scheduledDate <= now && $0.status == pendingStatus
        }

        do {
            let descriptor = FetchDescriptor<ScheduledEmail>(predicate: predicate)
            let dueEmails = try modelContext.fetch(descriptor)

            for scheduledEmail in dueEmails {
                scheduledEmail.status = .sending

                do {
                    let email = scheduledEmail.toEmail()
                    _ = try await gmailService.sendEmail(email)
                    scheduledEmail.status = .sent

                    // Record recipients for autocomplete
                    for recipient in email.to + email.cc + email.bcc {
                        await PeopleService.shared.addRecentEmail(recipient)
                    }

                    // Post success notification
                    await NotificationManager.shared.sendNotification(
                        title: "Scheduled Email Sent",
                        body: "Your scheduled email to \(email.to.first ?? "recipient") was sent successfully"
                    )
                } catch {
                    scheduledEmail.status = .failed

                    // Post failure notification
                    await NotificationManager.shared.sendNotification(
                        title: "Scheduled Email Failed",
                        body: "Failed to send scheduled email to \(scheduledEmail.to.first ?? "recipient"): \(error.localizedDescription)"
                    )

                    print("Failed to send scheduled email: \(error)")
                }
            }

            try modelContext.save()
        } catch {
            print("Error processing scheduled emails: \(error)")
        }
    }

    // MARK: - Clear / Reset

    func clearCurrentEmail() {
        currentEmail = Email()
        sendState = .idle
        error = nil
    }

    func resetState() {
        sendState = .idle
        error = nil
    }
}

// MARK: - Send Errors

enum SendError: Error, LocalizedError {
    case noRecipients
    case invalidScheduleDate

    var errorDescription: String? {
        switch self {
        case .noRecipients:
            return "Please add at least one recipient"
        case .invalidScheduleDate:
            return "Schedule date must be in the future"
        }
    }
}

// MARK: - Int Extension

extension Int {
    var nonZero: Int? {
        self == 0 ? nil : self
    }
}

// MARK: - Notification Manager

import UserNotifications

actor NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func sendNotification(title: String, body: String) async {
        let center = UNUserNotificationCenter.current()

        // Request permission if needed
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            try? await center.requestAuthorization(options: [.alert, .sound])
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }
}
