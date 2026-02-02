import Foundation

struct Email: Identifiable, Codable, Equatable {
    let id: UUID
    var to: [String]
    var cc: [String]
    var bcc: [String]
    var subject: String
    var body: String
    var isHTML: Bool
    var isMarkdown: Bool
    var attachments: [Attachment]
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        to: [String] = [],
        cc: [String] = [],
        bcc: [String] = [],
        subject: String = "",
        body: String = "",
        isHTML: Bool = false,
        isMarkdown: Bool = true,
        attachments: [Attachment] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
        self.isHTML = isHTML
        self.isMarkdown = isMarkdown
        self.attachments = attachments
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    var isEmpty: Bool {
        to.isEmpty && cc.isEmpty && bcc.isEmpty && subject.isEmpty && body.isEmpty
    }

    var hasRecipients: Bool {
        !to.isEmpty || !cc.isEmpty || !bcc.isEmpty
    }

    /// Escapes HTML special characters to prevent XSS
    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// Converts markdown to HTML
    func markdownToHTML(_ markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        var htmlLines: [String] = []
        var inUnorderedList = false
        var inOrderedList = false

        for line in lines {
            // Escape HTML first to prevent injection
            var processedLine = escapeHTML(line)

            // Bold: **text** or __text__
            processedLine = processedLine.replacingOccurrences(
                of: #"\*\*(.+?)\*\*"#,
                with: "<strong>$1</strong>",
                options: .regularExpression
            )
            processedLine = processedLine.replacingOccurrences(
                of: #"__(.+?)__"#,
                with: "<strong>$1</strong>",
                options: .regularExpression
            )

            // Italic: *text* or _text_
            processedLine = processedLine.replacingOccurrences(
                of: #"(?<!\*)\*([^*]+)\*(?!\*)"#,
                with: "<em>$1</em>",
                options: .regularExpression
            )
            processedLine = processedLine.replacingOccurrences(
                of: #"(?<!_)_([^_]+)_(?!_)"#,
                with: "<em>$1</em>",
                options: .regularExpression
            )

            // Code: `text`
            processedLine = processedLine.replacingOccurrences(
                of: #"`(.+?)`"#,
                with: "<code>$1</code>",
                options: .regularExpression
            )

            // Links: [text](url)
            processedLine = processedLine.replacingOccurrences(
                of: #"\[(.+?)\]\((.+?)\)"#,
                with: "<a href=\"$2\">$1</a>",
                options: .regularExpression
            )

            // Headers
            if processedLine.hasPrefix("### ") {
                processedLine = "<h3>\(String(processedLine.dropFirst(4)))</h3>"
            } else if processedLine.hasPrefix("## ") {
                processedLine = "<h2>\(String(processedLine.dropFirst(3)))</h2>"
            } else if processedLine.hasPrefix("# ") {
                processedLine = "<h1>\(String(processedLine.dropFirst(2)))</h1>"
            }
            // Unordered list: - item or * item
            else if processedLine.hasPrefix("- ") || processedLine.hasPrefix("* ") {
                if !inUnorderedList {
                    if inOrderedList {
                        htmlLines.append("</ol>")
                        inOrderedList = false
                    }
                    htmlLines.append("<ul>")
                    inUnorderedList = true
                }
                processedLine = "<li>\(String(processedLine.dropFirst(2)))</li>"
            }
            // Ordered list: 1. item
            else if processedLine.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                if !inOrderedList {
                    if inUnorderedList {
                        htmlLines.append("</ul>")
                        inUnorderedList = false
                    }
                    htmlLines.append("<ol>")
                    inOrderedList = true
                }
                if let range = processedLine.range(of: #"^\d+\. "#, options: .regularExpression) {
                    processedLine = "<li>\(String(processedLine[range.upperBound...]))</li>"
                }
            }
            // Regular paragraph or empty line
            else {
                if inUnorderedList {
                    htmlLines.append("</ul>")
                    inUnorderedList = false
                }
                if inOrderedList {
                    htmlLines.append("</ol>")
                    inOrderedList = false
                }
                if !processedLine.isEmpty && !processedLine.hasPrefix("<h") {
                    processedLine = "<p>\(processedLine)</p>"
                }
            }

            if !processedLine.isEmpty {
                htmlLines.append(processedLine)
            }
        }

        // Close any open lists
        if inUnorderedList {
            htmlLines.append("</ul>")
        }
        if inOrderedList {
            htmlLines.append("</ol>")
        }

        let body = htmlLines.joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: Menlo, monospace; }
        a { color: #007AFF; }
        ul, ol { margin: 8px 0; padding-left: 24px; }
        li { margin: 4px 0; }
        p { margin: 8px 0; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    /// Converts email to RFC 2822 format for Gmail API
    func toRFC2822(from: String) -> String {
        let boundary = "----=_Part_\(UUID().uuidString)"
        var message = ""

        // Headers
        message += "From: \(from)\r\n"

        if !to.isEmpty {
            message += "To: \(to.joined(separator: ", "))\r\n"
        }

        if !cc.isEmpty {
            message += "Cc: \(cc.joined(separator: ", "))\r\n"
        }

        if !bcc.isEmpty {
            message += "Bcc: \(bcc.joined(separator: ", "))\r\n"
        }

        message += "Subject: \(subject)\r\n"
        message += "MIME-Version: 1.0\r\n"

        if attachments.isEmpty {
            // Simple message without attachments
            if isMarkdown {
                message += "Content-Type: text/html; charset=utf-8\r\n"
                message += "\r\n"
                message += markdownToHTML(body)
            } else if isHTML {
                message += "Content-Type: text/html; charset=utf-8\r\n"
                message += "\r\n"
                message += body
            } else {
                message += "Content-Type: text/plain; charset=utf-8\r\n"
                message += "\r\n"
                message += body
            }
        } else {
            // Multipart message with attachments
            message += "Content-Type: multipart/mixed; boundary=\"\(boundary)\"\r\n"
            message += "\r\n"

            // Body part
            message += "--\(boundary)\r\n"
            if isMarkdown {
                message += "Content-Type: text/html; charset=utf-8\r\n"
                message += "\r\n"
                message += markdownToHTML(body)
            } else if isHTML {
                message += "Content-Type: text/html; charset=utf-8\r\n"
                message += "\r\n"
                message += body
            } else {
                message += "Content-Type: text/plain; charset=utf-8\r\n"
                message += "\r\n"
                message += body
            }
            message += "\r\n"

            // Attachment parts
            for attachment in attachments {
                message += "--\(boundary)\r\n"
                message += "Content-Type: \(attachment.mimeType); name=\"\(attachment.filename)\"\r\n"
                message += "Content-Disposition: attachment; filename=\"\(attachment.filename)\"\r\n"
                message += "Content-Transfer-Encoding: base64\r\n"
                message += "\r\n"
                message += attachment.data.base64EncodedString(options: .lineLength76Characters)
                message += "\r\n"
            }

            message += "--\(boundary)--\r\n"
        }

        return message
    }

    /// Encodes message for Gmail API (base64url)
    func toBase64URL(from: String) -> String {
        let raw = toRFC2822(from: from)
        guard let data = raw.data(using: .utf8) else { return "" }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

struct Attachment: Identifiable, Codable, Equatable {
    let id: UUID
    let filename: String
    let mimeType: String
    let data: Data

    init(id: UUID = UUID(), filename: String, mimeType: String, data: Data) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.data = data
    }
}

// MARK: - Email State for UI

enum EmailSendState: Equatable {
    case idle
    case pendingUndo(secondsRemaining: Int)
    case sending
    case sent
    case failed(Error)
    case cancelled
    case queued

    static func == (lhs: EmailSendState, rhs: EmailSendState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.sending, .sending), (.sent, .sent), (.cancelled, .cancelled), (.queued, .queued):
            return true
        case let (.pendingUndo(l), .pendingUndo(r)):
            return l == r
        case let (.failed(l), .failed(r)):
            return l.localizedDescription == r.localizedDescription
        default:
            return false
        }
    }
}
