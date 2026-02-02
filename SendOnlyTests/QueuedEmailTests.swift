import XCTest
import SwiftData
@testable import SendOnly

final class QueuedEmailTests: XCTestCase {

    // MARK: - Creation Tests

    func testQueuedEmailCreation() {
        let queued = QueuedEmail(
            to: ["test@example.com"],
            cc: ["cc@example.com"],
            bcc: [],
            subject: "Test Subject",
            body: "Test body content",
            isHTML: false
        )

        XCTAssertEqual(queued.to, ["test@example.com"])
        XCTAssertEqual(queued.cc, ["cc@example.com"])
        XCTAssertTrue(queued.bcc.isEmpty)
        XCTAssertEqual(queued.subject, "Test Subject")
        XCTAssertEqual(queued.body, "Test body content")
        XCTAssertFalse(queued.isHTML)
        XCTAssertEqual(queued.status, .pending)
        XCTAssertEqual(queued.attemptCount, 0)
        XCTAssertNil(queued.lastAttemptAt)
        XCTAssertNil(queued.lastError)
    }

    func testQueuedEmailFromEmail() {
        let email = Email(
            to: ["recipient@example.com"],
            cc: [],
            bcc: ["secret@example.com"],
            subject: "Original Subject",
            body: "Original body",
            isHTML: true
        )

        let queued = QueuedEmail(email: email)

        XCTAssertEqual(queued.to, email.to)
        XCTAssertEqual(queued.bcc, email.bcc)
        XCTAssertEqual(queued.subject, email.subject)
        XCTAssertEqual(queued.body, email.body)
        XCTAssertEqual(queued.isHTML, email.isHTML)
        XCTAssertEqual(queued.id, email.id)
        XCTAssertEqual(queued.status, .pending)
    }

    func testQueuedEmailFromEmailWithError() {
        let email = Email(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test"
        )

        let error = NSError(domain: "TestDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network unavailable"])
        let queued = QueuedEmail(email: email, error: error)

        XCTAssertEqual(queued.lastError, "Network unavailable")
        XCTAssertEqual(queued.status, .pending)
    }

    // MARK: - toEmail Conversion Tests

    func testToEmailConversion() {
        let queued = QueuedEmail(
            to: ["to@example.com"],
            cc: ["cc@example.com"],
            bcc: ["bcc@example.com"],
            subject: "Conversion Test",
            body: "<p>HTML content</p>",
            isHTML: true
        )

        let email = queued.toEmail()

        XCTAssertEqual(email.to, queued.to)
        XCTAssertEqual(email.cc, queued.cc)
        XCTAssertEqual(email.bcc, queued.bcc)
        XCTAssertEqual(email.subject, queued.subject)
        XCTAssertEqual(email.body, queued.body)
        XCTAssertEqual(email.isHTML, queued.isHTML)
        XCTAssertEqual(email.id, queued.id)
    }

    // MARK: - Status Tracking Tests

    func testStatusTransitions() {
        let queued = QueuedEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test"
        )

        XCTAssertEqual(queued.status, .pending)

        queued.status = .sending
        XCTAssertEqual(queued.status, .sending)

        queued.status = .sent
        XCTAssertEqual(queued.status, .sent)
    }

    func testFailedStatus() {
        let queued = QueuedEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test"
        )

        queued.status = .failed
        queued.lastError = "Server returned 500"
        queued.attemptCount = 1
        queued.lastAttemptAt = Date()

        XCTAssertEqual(queued.status, .failed)
        XCTAssertEqual(queued.lastError, "Server returned 500")
        XCTAssertEqual(queued.attemptCount, 1)
        XCTAssertNotNil(queued.lastAttemptAt)
    }

    func testAbandonedStatus() {
        let queued = QueuedEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test"
        )

        queued.status = .abandoned
        queued.attemptCount = 5
        queued.lastError = "Max retries exceeded"

        XCTAssertEqual(queued.status, .abandoned)
        XCTAssertEqual(queued.attemptCount, 5)
    }

    // MARK: - Attempt Tracking Tests

    func testAttemptCountIncrement() {
        let queued = QueuedEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test"
        )

        XCTAssertEqual(queued.attemptCount, 0)

        queued.attemptCount += 1
        XCTAssertEqual(queued.attemptCount, 1)

        queued.attemptCount += 1
        XCTAssertEqual(queued.attemptCount, 2)
    }

    func testLastAttemptAtUpdate() {
        let queued = QueuedEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test"
        )

        XCTAssertNil(queued.lastAttemptAt)

        let attemptTime = Date()
        queued.lastAttemptAt = attemptTime

        XCTAssertNotNil(queued.lastAttemptAt)
        XCTAssertEqual(queued.lastAttemptAt, attemptTime)
    }

    // MARK: - Display Properties Tests

    func testDisplayRecipient() {
        let queued = QueuedEmail(
            to: ["first@example.com", "second@example.com"],
            subject: "Test",
            body: "Test"
        )

        XCTAssertEqual(queued.displayRecipient, "first@example.com")
    }

    func testDisplayRecipientEmpty() {
        let queued = QueuedEmail(
            to: [],
            subject: "Test",
            body: "Test"
        )

        XCTAssertEqual(queued.displayRecipient, "Unknown recipient")
    }

    func testFormattedQueuedDate() {
        let queued = QueuedEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test",
            queuedAt: Date()
        )

        let formatted = queued.formattedQueuedDate
        XCTAssertFalse(formatted.isEmpty, "Formatted date should not be empty")
    }

    // MARK: - Error Tracking Tests

    func testErrorClearing() {
        let queued = QueuedEmail(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test"
        )

        queued.lastError = "Some error"
        XCTAssertEqual(queued.lastError, "Some error")

        queued.lastError = nil
        XCTAssertNil(queued.lastError)
    }
}
