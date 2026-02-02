import Foundation

/// Protocol for errors that can be classified as retryable
protocol RetryableError: Error {
    var isRetryable: Bool { get }
}

/// Configuration for retry behavior
struct RetryConfiguration {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval

    static let `default` = RetryConfiguration(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 4.0
    )

    /// Calculate delay for a given attempt (exponential backoff: 1s, 2s, 4s)
    func delay(for attempt: Int) -> TimeInterval {
        let delay = baseDelay * pow(2.0, Double(attempt - 1))
        return min(delay, maxDelay)
    }
}

/// Generic async retry wrapper with exponential backoff
func withRetry<T>(
    configuration: RetryConfiguration = .default,
    operation: @escaping () async throws -> T
) async throws -> T {
    var lastError: Error?

    for attempt in 1...configuration.maxRetries {
        do {
            return try await operation()
        } catch {
            lastError = error

            // Check if error is retryable
            if let retryableError = error as? RetryableError {
                guard retryableError.isRetryable else {
                    throw error
                }
            } else {
                // Non-RetryableError errors are not retried
                throw error
            }

            // Don't delay after the last attempt
            if attempt < configuration.maxRetries {
                let delay = configuration.delay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    // All retries exhausted
    throw lastError!
}

/// Wrapper that also accepts a shouldRetry closure for more control
func withRetry<T>(
    configuration: RetryConfiguration = .default,
    shouldRetry: @escaping (Error) -> Bool,
    operation: @escaping () async throws -> T
) async throws -> T {
    var lastError: Error?

    for attempt in 1...configuration.maxRetries {
        do {
            return try await operation()
        } catch {
            lastError = error

            guard shouldRetry(error) else {
                throw error
            }

            // Don't delay after the last attempt
            if attempt < configuration.maxRetries {
                let delay = configuration.delay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    throw lastError!
}
