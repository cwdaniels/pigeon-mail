import Foundation
import SwiftData

@Model
final class ScheduledEmail {
    var id: UUID
    var to: [String]
    var cc: [String]
    var bcc: [String]
    var subject: String
    var body: String
    var isHTML: Bool
    var scheduledDate: Date
    var createdAt: Date
    var status: ScheduleStatus

    init(
        id: UUID = UUID(),
        to: [String] = [],
        cc: [String] = [],
        bcc: [String] = [],
        subject: String = "",
        body: String = "",
        isHTML: Bool = false,
        scheduledDate: Date,
        createdAt: Date = Date(),
        status: ScheduleStatus = .pending
    ) {
        self.id = id
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
        self.isHTML = isHTML
        self.scheduledDate = scheduledDate
        self.createdAt = createdAt
        self.status = status
    }

    convenience init(email: Email, scheduledDate: Date) {
        self.init(
            id: email.id,
            to: email.to,
            cc: email.cc,
            bcc: email.bcc,
            subject: email.subject,
            body: email.body,
            isHTML: email.isHTML,
            scheduledDate: scheduledDate
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

    var isDue: Bool {
        scheduledDate <= Date() && status == .pending
    }

    var formattedScheduledDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: scheduledDate)
    }
}

enum ScheduleStatus: String, Codable {
    case pending
    case sending
    case sent
    case failed
    case cancelled
}
