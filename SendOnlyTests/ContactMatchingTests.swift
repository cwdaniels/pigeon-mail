import XCTest
@testable import SendOnly

final class ContactMatchingTests: XCTestCase {

    // MARK: - Test Contacts

    private func makeContact(name: String, email: String) -> Contact {
        Contact(id: UUID().uuidString, name: name, email: email, photoURL: nil)
    }

    // MARK: - Exact Match Tests

    func testExactMatchName() {
        let contact = makeContact(name: "John Smith", email: "john@example.com")
        XCTAssertEqual(contact.matchScore(for: "John Smith"), 4, "Exact name match should score 4")
    }

    func testExactMatchEmail() {
        let contact = makeContact(name: "John Smith", email: "john@example.com")
        XCTAssertEqual(contact.matchScore(for: "john@example.com"), 4, "Exact email match should score 4")
    }

    func testExactMatchCaseInsensitive() {
        let contact = makeContact(name: "John Smith", email: "john@example.com")
        XCTAssertEqual(contact.matchScore(for: "john smith"), 4, "Case-insensitive exact match should score 4")
        XCTAssertEqual(contact.matchScore(for: "JOHN@EXAMPLE.COM"), 4, "Case-insensitive email match should score 4")
    }

    // MARK: - Prefix Match Tests

    func testPrefixMatchName() {
        let contact = makeContact(name: "John Smith", email: "john@example.com")
        XCTAssertEqual(contact.matchScore(for: "John"), 3, "Name prefix match should score 3")
        XCTAssertEqual(contact.matchScore(for: "Jo"), 3, "Name prefix match should score 3")
    }

    func testPrefixMatchEmail() {
        let contact = makeContact(name: "John Smith", email: "john@example.com")
        XCTAssertEqual(contact.matchScore(for: "john@"), 3, "Email prefix match should score 3")
    }

    // MARK: - Word Boundary Match Tests

    func testWordBoundaryMatchFirstName() {
        let contact = makeContact(name: "John Smith", email: "john@example.com")
        // "Jo" at start of "John" is a prefix, so it scores 3
        XCTAssertEqual(contact.matchScore(for: "Jo"), 3, "Jo at start should be prefix match")
    }

    func testWordBoundaryMatchLastName() {
        let contact = makeContact(name: "John Smith", email: "john@example.com")
        // "Sm" matches start of word "Smith"
        XCTAssertEqual(contact.matchScore(for: "Sm"), 2, "Should match word boundary in last name")
        XCTAssertEqual(contact.matchScore(for: "Smith"), 2, "Should match word boundary")
    }

    func testWordBoundaryDoesNotMatchMiddle() {
        let contact = makeContact(name: "Banjo Player", email: "banjo@example.com")
        // "jo" should match "Banjo" as substring (score 1), not as word boundary
        XCTAssertEqual(contact.matchScore(for: "jo"), 1, "jo in 'Banjo' is substring, not word boundary")
    }

    func testJoMatchesJohnNotBanjo() {
        let john = makeContact(name: "John Doe", email: "john@example.com")
        let banjo = makeContact(name: "Banjo Player", email: "banjo@example.com")

        let johnScore = john.matchScore(for: "Jo")
        let banjoScore = banjo.matchScore(for: "Jo")

        XCTAssertGreaterThan(johnScore, banjoScore, "Jo should rank John higher than Banjo")
        XCTAssertEqual(johnScore, 3, "Jo should be prefix match for John")
        XCTAssertEqual(banjoScore, 1, "Jo should be substring match for Banjo")
    }

    // MARK: - Substring Match Tests

    func testSubstringMatchName() {
        let contact = makeContact(name: "Alexander", email: "alex@example.com")
        XCTAssertEqual(contact.matchScore(for: "ander"), 1, "Substring match should score 1")
    }

    func testSubstringMatchEmail() {
        let contact = makeContact(name: "John", email: "john.smith@example.com")
        // "example" matches at word boundary (after @ and before .)
        XCTAssertEqual(contact.matchScore(for: "example"), 2, "Email domain should match as word boundary")
        // A true substring that doesn't start at word boundary
        XCTAssertEqual(contact.matchScore(for: "xamp"), 1, "Mid-word substring should score 1")
    }

    // MARK: - No Match Tests

    func testNoMatch() {
        let contact = makeContact(name: "John Smith", email: "john@example.com")
        XCTAssertEqual(contact.matchScore(for: "xyz"), 0, "No match should score 0")
        XCTAssertEqual(contact.matchScore(for: "maria"), 0, "No match should score 0")
    }

    // MARK: - Case Insensitivity Tests

    func testCaseInsensitiveMatching() {
        let contact = makeContact(name: "John Smith", email: "John.Smith@Example.com")

        XCTAssertEqual(contact.matchScore(for: "JOHN"), 3, "Should match regardless of case")
        XCTAssertEqual(contact.matchScore(for: "smith"), 2, "Should match word boundary regardless of case")
        // "EXAMPLE" matches at word boundary in email (after @)
        XCTAssertEqual(contact.matchScore(for: "EXAMPLE"), 2, "Should match email word boundary regardless of case")
    }

    // MARK: - Edge Cases

    func testEmptyQuery() {
        let contact = makeContact(name: "John", email: "john@example.com")
        // Empty query should still work (matching everything as empty prefix)
        let score = contact.matchScore(for: "")
        XCTAssertEqual(score, 3, "Empty query should match as prefix")
    }

    func testContactWithEmptyName() {
        let contact = makeContact(name: "", email: "test@example.com")
        XCTAssertEqual(contact.matchScore(for: "test"), 3, "Should match email when name is empty")
    }

    func testSpecialCharactersInQuery() {
        let contact = makeContact(name: "John O'Brien", email: "john.obrien@example.com")
        // O'Brien splits into "O" and "Brien" at the apostrophe, so "O'Brien" won't match as word boundary
        // It will match as substring
        XCTAssertEqual(contact.matchScore(for: "O'Brien"), 1, "Should handle special characters as substring")
        XCTAssertEqual(contact.matchScore(for: "Brien"), 2, "Brien should match as word boundary")
    }
}
