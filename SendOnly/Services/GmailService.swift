import Foundation

enum GmailError: Error, LocalizedError, RetryableError {
    case notAuthenticated
    case invalidResponse
    case apiError(Int, String)
    case networkError(Error)
    case encodingError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Gmail"
        case .invalidResponse:
            return "Invalid response from Gmail API"
        case .apiError(let code, let message):
            return "Gmail API error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .encodingError:
            return "Failed to encode email message"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError:
            return true
        case .apiError(let code, _):
            // Retry on 5xx server errors, not on 4xx client errors
            return code >= 500 && code < 600
        case .notAuthenticated, .invalidResponse, .encodingError:
            return false
        }
    }
}

final class GmailService {
    static let shared = GmailService()

    private let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"
    private let authService = AuthService.shared

    private init() {}

    // MARK: - Send Email

    func sendEmail(_ email: Email) async throws -> SendResponse {
        try await withRetry {
            try await self.performSendEmail(email)
        }
    }

    private func performSendEmail(_ email: Email) async throws -> SendResponse {
        let token = try await authService.getAccessToken()
        let fromAddress = await authService.formattedFromAddress
        guard !fromAddress.isEmpty else {
            throw GmailError.notAuthenticated
        }

        let rawMessage = email.toBase64URL(from: fromAddress)

        guard !rawMessage.isEmpty else {
            throw GmailError.encodingError
        }

        let url = URL(string: "\(baseURL)/messages/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["raw": rawMessage]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GmailError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = parseErrorMessage(from: data)
                throw GmailError.apiError(httpResponse.statusCode, errorMessage)
            }

            return try JSONDecoder().decode(SendResponse.self, from: data)
        } catch let error as GmailError {
            throw error
        } catch {
            throw GmailError.networkError(error)
        }
    }

    // MARK: - Draft Management

    func createDraft(_ email: Email) async throws -> DraftResponse {
        try await withRetry {
            try await self.performCreateDraft(email)
        }
    }

    private func performCreateDraft(_ email: Email) async throws -> DraftResponse {
        let token = try await authService.getAccessToken()
        guard let userEmail = await authService.userEmail else {
            throw GmailError.notAuthenticated
        }

        let rawMessage = email.toBase64URL(from: userEmail)

        let url = URL(string: "\(baseURL)/drafts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "message": ["raw": rawMessage]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GmailError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = parseErrorMessage(from: data)
                throw GmailError.apiError(httpResponse.statusCode, errorMessage)
            }

            return try JSONDecoder().decode(DraftResponse.self, from: data)
        } catch let error as GmailError {
            throw error
        } catch {
            throw GmailError.networkError(error)
        }
    }

    func updateDraft(draftId: String, email: Email) async throws -> DraftResponse {
        try await withRetry {
            try await self.performUpdateDraft(draftId: draftId, email: email)
        }
    }

    private func performUpdateDraft(draftId: String, email: Email) async throws -> DraftResponse {
        let token = try await authService.getAccessToken()
        guard let userEmail = await authService.userEmail else {
            throw GmailError.notAuthenticated
        }

        let rawMessage = email.toBase64URL(from: userEmail)

        let url = URL(string: "\(baseURL)/drafts/\(draftId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "id": draftId,
            "message": ["raw": rawMessage]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GmailError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = parseErrorMessage(from: data)
                throw GmailError.apiError(httpResponse.statusCode, errorMessage)
            }

            return try JSONDecoder().decode(DraftResponse.self, from: data)
        } catch let error as GmailError {
            throw error
        } catch {
            throw GmailError.networkError(error)
        }
    }

    func deleteDraft(draftId: String) async throws {
        let token = try await authService.getAccessToken()

        let url = URL(string: "\(baseURL)/drafts/\(draftId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        // 204 No Content is success for DELETE
        guard httpResponse.statusCode == 204 || httpResponse.statusCode == 200 else {
            let errorMessage = parseErrorMessage(from: data)
            throw GmailError.apiError(httpResponse.statusCode, errorMessage)
        }
    }

    func listDrafts() async throws -> [DraftListItem] {
        let token = try await authService.getAccessToken()

        let url = URL(string: "\(baseURL)/drafts?maxResults=20")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = parseErrorMessage(from: data)
            throw GmailError.apiError(httpResponse.statusCode, errorMessage)
        }

        let listResponse = try JSONDecoder().decode(DraftListResponse.self, from: data)
        return listResponse.drafts ?? []
    }

    func getDraft(draftId: String) async throws -> DraftDetail {
        let token = try await authService.getAccessToken()

        let url = URL(string: "\(baseURL)/drafts/\(draftId)?format=full")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = parseErrorMessage(from: data)
            throw GmailError.apiError(httpResponse.statusCode, errorMessage)
        }

        return try JSONDecoder().decode(DraftDetail.self, from: data)
    }

    // MARK: - Sent Messages

    func listSentMessages(maxResults: Int = 5) async throws -> [MessageListItem] {
        let token = try await authService.getAccessToken()

        let url = URL(string: "\(baseURL)/messages?labelIds=SENT&maxResults=\(maxResults)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = parseErrorMessage(from: data)
            throw GmailError.apiError(httpResponse.statusCode, errorMessage)
        }

        let listResponse = try JSONDecoder().decode(MessageListResponse.self, from: data)
        return listResponse.messages ?? []
    }

    func getMessage(messageId: String) async throws -> MessageMetadata {
        let token = try await authService.getAccessToken()

        let url = URL(string: "\(baseURL)/messages/\(messageId)?format=metadata&metadataHeaders=To&metadataHeaders=Subject&metadataHeaders=Date")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = parseErrorMessage(from: data)
            throw GmailError.apiError(httpResponse.statusCode, errorMessage)
        }

        return try JSONDecoder().decode(MessageMetadata.self, from: data)
    }

    func countTodaySentMessages() async throws -> Int {
        let token = try await authService.getAccessToken()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let today = formatter.string(from: Date())

        let query = "after:\(today)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "after:\(today)"
        let url = URL(string: "\(baseURL)/messages?labelIds=SENT&q=\(query)&maxResults=100")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = parseErrorMessage(from: data)
            throw GmailError.apiError(httpResponse.statusCode, errorMessage)
        }

        let listResponse = try JSONDecoder().decode(MessageListResponse.self, from: data)
        return listResponse.messages?.count ?? 0
    }

    // MARK: - Helpers

    private func parseErrorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}

// MARK: - Response Models

struct SendResponse: Codable {
    let id: String
    let threadId: String
    let labelIds: [String]?
}

struct DraftResponse: Codable {
    let id: String
    let message: DraftMessage?
}

struct DraftMessage: Codable {
    let id: String?
    let threadId: String?
}

struct DraftListResponse: Codable {
    let drafts: [DraftListItem]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct DraftListItem: Codable, Identifiable {
    let id: String
    let message: DraftMessageSummary?
}

struct DraftMessageSummary: Codable {
    let id: String?
    let threadId: String?
}

struct DraftDetail: Codable {
    let id: String
    let message: DraftFullMessage?

    func toEmail() -> Email {
        guard let message = message else { return Email() }
        return message.toEmail()
    }
}

struct DraftFullMessage: Codable {
    let id: String?
    let threadId: String?
    let payload: MessagePayload?

    func toEmail() -> Email {
        guard let payload = payload else { return Email() }

        var email = Email()
        var bodyText = ""

        // Parse headers
        if let headers = payload.headers {
            for header in headers {
                switch header.name.lowercased() {
                case "to":
                    email.to = parseRecipients(header.value)
                case "cc":
                    email.cc = parseRecipients(header.value)
                case "bcc":
                    email.bcc = parseRecipients(header.value)
                case "subject":
                    email.subject = header.value
                default:
                    break
                }
            }
        }

        // Parse body from parts or directly
        if let parts = payload.parts {
            bodyText = extractBodyFromParts(parts)
        } else if let body = payload.body, let data = body.data {
            bodyText = decodeBase64URL(data)
        }

        email.body = bodyText
        return email
    }

    private func parseRecipients(_ value: String) -> [String] {
        // Handle formats like "Name <email@example.com>, other@example.com"
        let components = value.components(separatedBy: ",")
        return components.compactMap { component in
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            // Extract email from "Name <email>" format
            if let start = trimmed.range(of: "<"),
               let end = trimmed.range(of: ">") {
                return String(trimmed[start.upperBound..<end.lowerBound])
            }
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private func extractBodyFromParts(_ parts: [MessagePart]) -> String {
        for part in parts {
            // Prefer plain text
            if part.mimeType == "text/plain", let body = part.body, let data = body.data {
                return decodeBase64URL(data)
            }
            // Recurse into nested parts
            if let nestedParts = part.parts {
                let nested = extractBodyFromParts(nestedParts)
                if !nested.isEmpty { return nested }
            }
        }
        // Fall back to HTML if no plain text
        for part in parts {
            if part.mimeType == "text/html", let body = part.body, let data = body.data {
                return decodeBase64URL(data)
            }
        }
        return ""
    }

    private func decodeBase64URL(_ base64URL: String) -> String {
        // Convert base64url to standard base64
        var base64 = base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}

struct MessagePayload: Codable {
    let partId: String?
    let mimeType: String?
    let headers: [MessageHeader]?
    let body: MessageBody?
    let parts: [MessagePart]?
}

struct MessageHeader: Codable {
    let name: String
    let value: String
}

struct MessageBody: Codable {
    let size: Int?
    let data: String?
}

struct MessagePart: Codable {
    let partId: String?
    let mimeType: String?
    let body: MessageBody?
    let parts: [MessagePart]?
}

// MARK: - Sent Message Models

struct MessageListResponse: Codable {
    let messages: [MessageListItem]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct MessageListItem: Codable, Identifiable {
    let id: String
    let threadId: String?
}

struct MessageMetadata: Codable {
    let id: String
    let payload: MessagePayload?

    func toSentSummary() -> SentSummary {
        var to = "(No recipient)"
        var subject = "(No subject)"
        var date: Date?

        if let headers = payload?.headers {
            for header in headers {
                switch header.name.lowercased() {
                case "to":
                    // Extract just the email or first name
                    let value = header.value
                    if let start = value.range(of: "<"),
                       let end = value.range(of: ">") {
                        to = String(value[start.upperBound..<end.lowerBound])
                    } else {
                        to = value.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? value
                    }
                case "subject":
                    subject = header.value.isEmpty ? "(No subject)" : header.value
                case "date":
                    let formatter = DateFormatter()
                    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                    date = formatter.date(from: header.value)
                default:
                    break
                }
            }
        }

        return SentSummary(id: id, to: to, subject: subject, date: date)
    }
}

struct SentSummary: Identifiable {
    let id: String
    let to: String
    let subject: String
    let date: Date?
}
