import Foundation
import SwiftData

enum QueuedEmailStatus: String, Codable {
    case pending
    case sending
    case failed
    case abandoned
    case sent
}

@Model
final class QueuedEmail {
    var id: UUID
    var to: [String]
    var cc: [String]
    var bcc: [String]
    var subject: String
    var body: String
    var isHTML: Bool

    // Tracking
    var queuedAt: Date
    var lastAttemptAt: Date?
    var attemptCount: Int
    var lastError: String?
    var status: QueuedEmailStatus

    init(
        id: UUID = UUID(),
        to: [String] = [],
        cc: [String] = [],
        bcc: [String] = [],
        subject: String = "",
        body: String = "",
        isHTML: Bool = false,
        queuedAt: Date = Date(),
        lastAttemptAt: Date? = nil,
        attemptCount: Int = 0,
        lastError: String? = nil,
        status: QueuedEmailStatus = .pending
    ) {
        self.id = id
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
        self.isHTML = isHTML
        self.queuedAt = queuedAt
        self.lastAttemptAt = lastAttemptAt
        self.attemptCount = attemptCount
        self.lastError = lastError
        self.status = status
    }

    convenience init(email: Email, error: Error? = nil) {
        self.init(
            id: email.id,
            to: email.to,
            cc: email.cc,
            bcc: email.bcc,
            subject: email.subject,
            body: email.body,
            isHTML: email.isHTML,
            queuedAt: Date(),
            lastAttemptAt: nil,
            attemptCount: 0,
            lastError: error?.localizedDescription,
            status: .pending
        )
    }

    func toEmail() -> Email {
        Email(
            id: id,
            to: to,
            cc: cc,
            bcc: bcc,
            subject: subject,
            body: body,
            isHTML: isHTML
        )
    }

    var formattedQueuedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: queuedAt, relativeTo: Date())
    }

    var displayRecipient: String {
        to.first ?? "Unknown recipient"
    }
}
