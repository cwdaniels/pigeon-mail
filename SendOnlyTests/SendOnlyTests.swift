import XCTest
@testable import SendOnly

final class SendOnlyTests: XCTestCase {

    // MARK: - Email Model Tests

    func testEmailIsEmpty() {
        let email = Email()
        XCTAssertTrue(email.isEmpty)
    }

    func testEmailIsNotEmptyWithRecipient() {
        var email = Email()
        email.to = ["test@example.com"]
        XCTAssertFalse(email.isEmpty)
    }

    func testEmailHasRecipients() {
        var email = Email()
        XCTAssertFalse(email.hasRecipients)

        email.to = ["test@example.com"]
        XCTAssertTrue(email.hasRecipients)
    }

    func testEmailRFC2822Format() {
        var email = Email()
        email.to = ["recipient@example.com"]
        email.subject = "Test Subject"
        email.body = "Test body content"

        let raw = email.toRFC2822(from: "sender@example.com")

        XCTAssertTrue(raw.contains("From: sender@example.com"))
        XCTAssertTrue(raw.contains("To: recipient@example.com"))
        XCTAssertTrue(raw.contains("Subject: Test Subject"))
        XCTAssertTrue(raw.contains("Test body content"))
    }

    func testEmailBase64URLEncoding() {
        var email = Email()
        email.to = ["test@example.com"]
        email.subject = "Test"
        email.body = "Hello"

        let encoded = email.toBase64URL(from: "from@example.com")

        XCTAssertFalse(encoded.isEmpty)
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
        XCTAssertFalse(encoded.contains("="))
    }

    // MARK: - Contact Model Tests

    func testContactDisplayName() {
        let contactWithName = Contact(name: "John Doe", email: "john@example.com")
        XCTAssertEqual(contactWithName.displayName, "John Doe")

        let contactWithoutName = Contact(name: "", email: "john@example.com")
        XCTAssertEqual(contactWithoutName.displayName, "john@example.com")
    }

    func testContactMatches() {
        let contact = Contact(name: "John Doe", email: "john@example.com")

        XCTAssertTrue(contact.matches("john"))
        XCTAssertTrue(contact.matches("Doe"))
        XCTAssertTrue(contact.matches("example"))
        XCTAssertFalse(contact.matches("jane"))
    }

    // MARK: - Schedule Preset Tests

    func testSchedulePresetDatesAreInFuture() {
        for preset in SchedulePreset.allCases {
            XCTAssertGreaterThan(preset.date, Date(), "\(preset) should be in the future")
        }
    }

    // MARK: - OAuth Tokens Tests

    func testOAuthTokensExpiry() {
        let tokens = OAuthTokens(
            accessToken: "test",
            refreshToken: nil,
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: nil
        )

        XCTAssertFalse(tokens.isExpired)
    }

    func testOAuthTokensExpired() {
        // Create tokens that expired 1 hour ago
        let tokens = OAuthTokens(
            accessToken: "test",
            refreshToken: nil,
            tokenType: "Bearer",
            expiresIn: -3600, // Negative = already expired
            scope: nil
        )

        XCTAssertTrue(tokens.isExpired)
    }
}
