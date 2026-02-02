import XCTest
@testable import SendOnly

final class NetworkRetryTests: XCTestCase {

    // MARK: - Mock Errors

    enum MockNetworkError: Error, RetryableError {
        case networkFailure
        case serverError(Int)
        case authError
        case clientError(Int)

        var isRetryable: Bool {
            switch self {
            case .networkFailure:
                return true
            case .serverError(let code):
                return code >= 500 && code < 600
            case .authError:
                return false
            case .clientError:
                return false
            }
        }
    }

    // MARK: - Retry on Network Error

    func testRetryOnNetworkError() async throws {
        var attemptCount = 0

        do {
            _ = try await withRetry(configuration: .default) {
                attemptCount += 1
                if attemptCount < 3 {
                    throw MockNetworkError.networkFailure
                }
                return "success"
            }
        } catch {
            // Should not throw - should succeed on 3rd attempt
            XCTFail("Should have succeeded after retries")
        }

        XCTAssertEqual(attemptCount, 3, "Should have retried 3 times")
    }

    func testExhaustsRetriesOnPersistentNetworkError() async throws {
        var attemptCount = 0

        do {
            _ = try await withRetry(configuration: .default) {
                attemptCount += 1
                throw MockNetworkError.networkFailure
            }
            XCTFail("Should have thrown after exhausting retries")
        } catch {
            XCTAssertTrue(error is MockNetworkError)
        }

        XCTAssertEqual(attemptCount, 3, "Should have attempted max retries")
    }

    // MARK: - No Retry on Auth Error

    func testNoRetryOnAuthError() async throws {
        var attemptCount = 0

        do {
            _ = try await withRetry(configuration: .default) {
                attemptCount += 1
                throw MockNetworkError.authError
            }
            XCTFail("Should have thrown immediately")
        } catch {
            XCTAssertTrue(error is MockNetworkError)
        }

        XCTAssertEqual(attemptCount, 1, "Should not retry auth errors")
    }

    // MARK: - Retry on 5xx, No Retry on 4xx

    func testRetryOn5xxError() async throws {
        var attemptCount = 0

        do {
            _ = try await withRetry(configuration: .default) {
                attemptCount += 1
                if attemptCount < 2 {
                    throw MockNetworkError.serverError(503)
                }
                return "success"
            }
        } catch {
            XCTFail("Should have succeeded after retry")
        }

        XCTAssertEqual(attemptCount, 2, "Should have retried on 503")
    }

    func testNoRetryOn4xxError() async throws {
        var attemptCount = 0

        do {
            _ = try await withRetry(configuration: .default) {
                attemptCount += 1
                throw MockNetworkError.clientError(400)
            }
            XCTFail("Should have thrown immediately")
        } catch {
            XCTAssertTrue(error is MockNetworkError)
        }

        XCTAssertEqual(attemptCount, 1, "Should not retry 4xx errors")
    }

    // MARK: - Configuration Tests

    func testExponentialBackoffDelays() {
        let config = RetryConfiguration.default

        XCTAssertEqual(config.delay(for: 1), 1.0, "First delay should be 1s")
        XCTAssertEqual(config.delay(for: 2), 2.0, "Second delay should be 2s")
        XCTAssertEqual(config.delay(for: 3), 4.0, "Third delay should be 4s")
    }

    func testDelayCapAtMaxDelay() {
        let config = RetryConfiguration(maxRetries: 5, baseDelay: 1.0, maxDelay: 4.0)

        XCTAssertEqual(config.delay(for: 4), 4.0, "Should cap at maxDelay")
        XCTAssertEqual(config.delay(for: 5), 4.0, "Should cap at maxDelay")
    }

    // MARK: - Success on First Attempt

    func testSuccessOnFirstAttempt() async throws {
        var attemptCount = 0

        let result = try await withRetry(configuration: .default) {
            attemptCount += 1
            return "immediate success"
        }

        XCTAssertEqual(result, "immediate success")
        XCTAssertEqual(attemptCount, 1, "Should succeed on first attempt")
    }
}
