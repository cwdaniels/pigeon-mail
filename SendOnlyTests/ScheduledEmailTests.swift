import XCTest
import SwiftData
@testable import SendOnly

final class ScheduledEmailTests: XCTestCase {

    // MARK: - Creation Tests

    func testScheduledEmailCreation() {
        let scheduledDate = Date().addingTimeInterval(3600) // 1 hour from now
        let scheduled = ScheduledEmail(
            to: ["test@example.com"],
            cc: ["cc@example.com"],
            bcc: [],
            subject: "Test Subject",
            body: "Test body content",
            isHTML: false,
            scheduledDate: scheduledDate
        )

        XCTAssertEqual(scheduled.to, ["test@example.com"])
        XCTAssertEqual(scheduled.cc, ["cc@example.com"])
        XCTAssertTrue(scheduled.bcc.isEmpty)
        XCTAssertEqual(scheduled.subject, "Test Subject")
        XCTAssertEqual(scheduled.body, "Test body content")
        XCTAssertFalse(scheduled.isHTML)
        XCTAssertEqual(scheduled.scheduledDate, scheduledDate)
        XCTAssertEqual(scheduled.status, .pending)
    }

    func testScheduledEmailFromEmail() {
        let email = Email(
            to: ["recipient@example.com"],
            cc: [],
            bcc: ["secret@example.com"],
            subject: "Original Subject",
            body: "Original body",
            isHTML: true
        )

        let scheduledDate = Date().addingTimeInterval(7200)
        let scheduled = ScheduledEmail(email: email, scheduledDate: scheduledDate)

        XCTAssertEqual(scheduled.to, email.to)
        XCTAssertEqual(scheduled.bcc, email.bcc)
        XCTAssertEqual(scheduled.subject, email.subject)
        XCTAssertEqual(scheduled.body, email.body)
        XCTAssertEqual(scheduled.isHTML, email.isHTML)
        XCTAssertEqual(scheduled.id, email.id)
    }

    // MARK: - isDue Logic Tests

    func testIsDueWhenPastScheduledDate() {
        let pastDate = Date().addingTimeInterval(-60) // 1 minute ago
        let scheduled = ScheduledEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test",
            scheduledDate: pastDate,
            status: .pending
        )

        XCTAssertTrue(scheduled.isDue, "Should be due when scheduled date is in the past and status is pending")
    }

    func testIsDueWhenExactlyNow() {
        let now = Date()
        let scheduled = ScheduledEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test",
            scheduledDate: now,
            status: .pending
        )

        XCTAssertTrue(scheduled.isDue, "Should be due when scheduled date is now")
    }

    func testNotDueWhenFutureDate() {
        let futureDate = Date().addingTimeInterval(3600)
        let scheduled = ScheduledEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test",
            scheduledDate: futureDate,
            status: .pending
        )

        XCTAssertFalse(scheduled.isDue, "Should not be due when scheduled date is in the future")
    }

    func testNotDueWhenAlreadySent() {
        let pastDate = Date().addingTimeInterval(-60)
        let scheduled = ScheduledEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test",
            scheduledDate: pastDate,
            status: .sent
        )

        XCTAssertFalse(scheduled.isDue, "Should not be due when status is sent")
    }

    func testNotDueWhenCancelled() {
        let pastDate = Date().addingTimeInterval(-60)
        let scheduled = ScheduledEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test",
            scheduledDate: pastDate,
            status: .cancelled
        )

        XCTAssertFalse(scheduled.isDue, "Should not be due when cancelled")
    }

    // MARK: - toEmail Conversion Tests

    func testToEmailConversion() {
        let scheduled = ScheduledEmail(
            to: ["to@example.com"],
            cc: ["cc@example.com"],
            bcc: ["bcc@example.com"],
            subject: "Conversion Test",
            body: "<p>HTML content</p>",
            isHTML: true,
            scheduledDate: Date()
        )

        let email = scheduled.toEmail()

        XCTAssertEqual(email.to, scheduled.to)
        XCTAssertEqual(email.cc, scheduled.cc)
        XCTAssertEqual(email.bcc, scheduled.bcc)
        XCTAssertEqual(email.subject, scheduled.subject)
        XCTAssertEqual(email.body, scheduled.body)
        XCTAssertEqual(email.isHTML, scheduled.isHTML)
        XCTAssertEqual(email.id, scheduled.id)
    }

    // MARK: - Status Tests

    func testStatusTransitions() {
        let scheduled = ScheduledEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test",
            scheduledDate: Date()
        )

        XCTAssertEqual(scheduled.status, .pending)

        scheduled.status = .sending
        XCTAssertEqual(scheduled.status, .sending)

        scheduled.status = .sent
        XCTAssertEqual(scheduled.status, .sent)
    }

    func testFailedStatus() {
        let scheduled = ScheduledEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test",
            scheduledDate: Date()
        )

        scheduled.status = .failed
        XCTAssertEqual(scheduled.status, .failed)
    }

    // MARK: - Formatted Date Tests

    func testFormattedScheduledDate() {
        let scheduled = ScheduledEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test",
            scheduledDate: Date()
        )

        let formatted = scheduled.formattedScheduledDate
        XCTAssertFalse(formatted.isEmpty, "Formatted date should not be empty")
    }
}
