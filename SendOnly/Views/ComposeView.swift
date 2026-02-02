import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import WebKit

// Shared coordinator for text editor formatting
class TextEditorCoordinator: ObservableObject {
    weak var textView: NSTextView?

    func applyFormatting(prefix: String, suffix: String) {
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange()
        let currentText = textView.string as NSString

        if selectedRange.length > 0 {
            // Text is selected - wrap it
            let selectedText = currentText.substring(with: selectedRange)
            let replacement = "\(prefix)\(selectedText)\(suffix)"

            if textView.shouldChangeText(in: selectedRange, replacementString: replacement) {
                textView.replaceCharacters(in: selectedRange, with: replacement)
                textView.didChangeText()

                // Position cursor after the formatted text
                let newCursorPos = selectedRange.location + replacement.count
                textView.setSelectedRange(NSRange(location: newCursorPos, length: 0))
            }
        } else {
            // No selection - insert placeholder
            let placeholder = "\(prefix)text\(suffix)"
            let insertLocation = selectedRange.location

            if textView.shouldChangeText(in: selectedRange, replacementString: placeholder) {
                textView.replaceCharacters(in: selectedRange, with: placeholder)
                textView.didChangeText()

                // Select the placeholder text
                let selectStart = insertLocation + prefix.count
                textView.setSelectedRange(NSRange(location: selectStart, length: 4))
            }
        }
    }

    func insertAtLineStart(_ prefix: String) {
        guard let textView = textView else { return }

        let currentText = textView.string as NSString
        let selectedRange = textView.selectedRange()

        // Find the start of the current line
        let lineRange = currentText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let insertLocation = lineRange.location

        // Check if already at line start or need newline
        var textToInsert = prefix
        if insertLocation > 0 {
            let charBefore = currentText.substring(with: NSRange(location: insertLocation - 1, length: 1))
            if charBefore != "\n" {
                textToInsert = "\n" + prefix
            }
        }

        let insertRange = NSRange(location: selectedRange.location, length: 0)
        if textView.shouldChangeText(in: insertRange, replacementString: textToInsert) {
            textView.replaceCharacters(in: insertRange, with: textToInsert)
            textView.didChangeText()
        }
    }

    func insertLink(text: String, url: String) {
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange()
        let linkMarkdown = "[\(text)](\(url))"

        if textView.shouldChangeText(in: selectedRange, replacementString: linkMarkdown) {
            textView.replaceCharacters(in: selectedRange, with: linkMarkdown)
            textView.didChangeText()
        }
    }

    func getSelectedText() -> String {
        guard let textView = textView else { return "" }
        let selectedRange = textView.selectedRange()
        if selectedRange.length > 0 {
            return (textView.string as NSString).substring(with: selectedRange)
        }
        return ""
    }
}

struct ComposeView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var emailManager: EmailManager
    @StateObject private var draftManager = DraftManager.shared
    @StateObject private var editorCoordinator = TextEditorCoordinator()

    @State private var toField = ""
    @State private var ccField = ""
    @State private var bccField = ""
    @State private var showCC = false
    @State private var showBCC = false

    @State private var showSchedulePicker = false
    @State private var showFilePicker = false
    @State private var showMarkdownPreview = false
    @State private var showLinkSheet = false
    @State private var linkText = ""
    @State private var linkURL = ""
    @State private var contactSuggestions: [Contact] = []
    @State private var activeField: RecipientField = .to

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    enum RecipientField {
        case to, cc, bcc
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                composeHeader

                Divider()

                // Recipients
                VStack(spacing: 8) {
                    recipientRow(label: "To:", text: $toField, field: .to, emails: $emailManager.currentEmail.to)

                    if showCC {
                        recipientRow(label: "Cc:", text: $ccField, field: .cc, emails: $emailManager.currentEmail.cc)
                    }

                    if showBCC {
                        recipientRow(label: "Bcc:", text: $bccField, field: .bcc, emails: $emailManager.currentEmail.bcc)
                    }

                    // Subject
                    HStack {
                        Text("Subject:")
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)

                        TextField("", text: $emailManager.currentEmail.subject)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)

                Divider()

                // Body with markdown toolbar
                VStack(alignment: .leading, spacing: 0) {
                    // Formatting toolbar
                    HStack(spacing: 12) {
                        Button { editorCoordinator.applyFormatting(prefix: "**", suffix: "**") } label: {
                            Image(systemName: "bold")
                        }
                        .keyboardShortcut("b", modifiers: .command)
                        .help("Bold (⌘B)")

                        Button { editorCoordinator.applyFormatting(prefix: "*", suffix: "*") } label: {
                            Image(systemName: "italic")
                        }
                        .keyboardShortcut("i", modifiers: .command)
                        .help("Italic (⌘I)")

                        Button {
                            linkText = editorCoordinator.getSelectedText()
                            showLinkSheet = true
                        } label: {
                            Image(systemName: "link")
                        }
                        .keyboardShortcut("k", modifiers: .command)
                        .help("Insert Link (⌘K)")

                        Divider().frame(height: 16)

                        Button { editorCoordinator.insertAtLineStart("- ") } label: {
                            Image(systemName: "list.bullet")
                        }
                        .help("Bullet List")

                        Button { insertNumberedList() } label: {
                            Image(systemName: "list.number")
                        }
                        .help("Numbered List")

                        Button { editorCoordinator.applyFormatting(prefix: "`", suffix: "`") } label: {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                        }
                        .help("Code")

                        Spacer()

                        Button("Preview") {
                            showMarkdownPreview = true
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))

                    MarkdownTextEditor(text: $emailManager.currentEmail.body, coordinator: editorCoordinator)
                        .frame(maxHeight: .infinity)
                }

                // Attachments
                if !emailManager.currentEmail.attachments.isEmpty {
                    Divider()
                    attachmentsView
                }

                Divider()

                // Footer
                composeFooter
            }

            // Contact suggestions overlay
            if !contactSuggestions.isEmpty {
                contactSuggestionsOverlay
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onChange(of: toField) { _, newValue in
            handleRecipientFieldChange(newValue, field: .to)
        }
        .onChange(of: ccField) { _, newValue in
            handleRecipientFieldChange(newValue, field: .cc)
        }
        .onChange(of: bccField) { _, newValue in
            handleRecipientFieldChange(newValue, field: .bcc)
        }
        .onChange(of: emailManager.currentEmail) { _, newEmail in
            draftManager.emailDidChange(newEmail)
        }
        .sheet(isPresented: $showSchedulePicker) {
            SchedulePickerView { date in
                scheduleEmail(for: date)
            }
        }
        .sheet(isPresented: $showMarkdownPreview) {
            MarkdownPreviewView(markdown: emailManager.currentEmail.body)
        }
        .sheet(isPresented: $showLinkSheet) {
            InsertLinkView(text: $linkText, url: $linkURL) { text, url in
                editorCoordinator.insertLink(text: text, url: url)
                linkText = ""
                linkURL = ""
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .alert("Error", isPresented: .constant(emailManager.error != nil)) {
            Button("OK") {
                emailManager.resetState()
            }
        } message: {
            Text(emailManager.error?.localizedDescription ?? "An error occurred")
        }
    }

    // MARK: - Header

    private var composeHeader: some View {
        HStack {
            Text("New Message")
                .font(.headline)

            Spacer()

            // CC/BCC toggles
            Button(showCC ? "Hide Cc" : "Cc") {
                showCC.toggle()
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Button(showBCC ? "Hide Bcc" : "Bcc") {
                showBCC.toggle()
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            // Draft status
            if !draftManager.syncStatusText.isEmpty {
                Text(draftManager.syncStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Recipient Row

    private func recipientRow(label: String, text: Binding<String>, field: RecipientField, emails: Binding<[String]>) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)

            // Email chips
            FlowLayout(spacing: 4) {
                ForEach(emails.wrappedValue, id: \.self) { email in
                    EmailChip(email: email) {
                        emails.wrappedValue.removeAll { $0 == email }
                    }
                }

                // Text field for adding more
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 100)
                    .onSubmit {
                        addEmailFromField(text: text, emails: emails)
                    }
                    .onChange(of: text.wrappedValue) { _, _ in
                        activeField = field
                    }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Footer

    // MARK: - Attachments View

    private var attachmentsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(emailManager.currentEmail.attachments) { attachment in
                    AttachmentChip(attachment: attachment) {
                        emailManager.currentEmail.attachments.removeAll { $0.id == attachment.id }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Footer

    private var composeFooter: some View {
        HStack {
            // From address
            Text("From: \(authService.formattedFromAddress)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // Attach button
            Button {
                showFilePicker = true
            } label: {
                Label("Attach", systemImage: "paperclip")
            }

            Button("Discard") {
                discardDraft()
            }
            .keyboardShortcut(.escape)

            Button {
                showSchedulePicker = true
            } label: {
                Label("Schedule", systemImage: "clock")
            }
            .keyboardShortcut(.return, modifiers: [.command, .shift])

            Button {
                if emailManager.sendEmail() {
                    dismiss()
                }
            } label: {
                Label("Send", systemImage: "paperplane.fill")
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!emailManager.currentEmail.hasRecipients)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Contact Suggestions

    private var contactSuggestionsOverlay: some View {
        VStack {
            Spacer()
                .frame(height: 120) // Position below recipient fields

            HStack {
                Spacer()
                    .frame(width: 70)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(contactSuggestions) { contact in
                        Button {
                            selectContact(contact)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(contact.displayName)
                                        .fontWeight(.medium)
                                    Text(contact.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if contact.id != contactSuggestions.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .shadow(radius: 4)
                .frame(maxWidth: 350)

                Spacer()
            }

            Spacer()
        }
    }

    // MARK: - Overlays

    private var sendingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Sending...")
                    .font(.headline)
            }
            .padding(40)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
        }
    }

    private var sentOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("Sent!")
                    .font(.headline)
            }
            .padding(40)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
        }
    }

    // MARK: - Actions

    private func handleRecipientFieldChange(_ value: String, field: RecipientField) {
        activeField = field

        // Check for comma or space to add email
        if value.contains(",") || value.hasSuffix(" ") {
            let cleaned = value.trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            if isValidEmail(cleaned) {
                switch field {
                case .to:
                    emailManager.currentEmail.to.append(cleaned)
                    toField = ""
                case .cc:
                    emailManager.currentEmail.cc.append(cleaned)
                    ccField = ""
                case .bcc:
                    emailManager.currentEmail.bcc.append(cleaned)
                    bccField = ""
                }
                contactSuggestions = []
                return
            }
        }

        // Search for contacts
        if value.count >= 2 {
            Task {
                let suggestions = await PeopleService.shared.searchContacts(query: value)
                contactSuggestions = suggestions
            }
        } else {
            contactSuggestions = []
        }
    }

    private func addEmailFromField(text: Binding<String>, emails: Binding<[String]>) {
        let email = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidEmail(email) {
            emails.wrappedValue.append(email)
            text.wrappedValue = ""
            contactSuggestions = []
        }
    }

    private func selectContact(_ contact: Contact) {
        switch activeField {
        case .to:
            emailManager.currentEmail.to.append(contact.email)
            toField = ""
        case .cc:
            emailManager.currentEmail.cc.append(contact.email)
            ccField = ""
        case .bcc:
            emailManager.currentEmail.bcc.append(contact.email)
            bccField = ""
        }
        contactSuggestions = []
    }

    private func scheduleEmail(for date: Date) {
        do {
            try emailManager.scheduleEmail(for: date, modelContext: modelContext)
            dismiss()
        } catch {
            emailManager.error = error
        }
    }

    private func discardDraft() {
        Task {
            await draftManager.deleteDraft()
            emailManager.clearCurrentEmail()
            dismiss()
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return email.range(of: emailRegex, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: - Markdown Formatting

    private func insertNumberedList() {
        guard let textView = editorCoordinator.textView else { return }

        let currentText = textView.string as NSString
        let selectedRange = textView.selectedRange()

        // Find the current line to determine the next number
        let lineRange = currentText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let textBeforeCursor = currentText.substring(to: lineRange.location)
        let lines = textBeforeCursor.components(separatedBy: "\n")

        var lastNumber = 0
        for line in lines.reversed() {
            if let match = line.range(of: #"^(\d+)\. "#, options: .regularExpression) {
                let numStr = String(line[match]).dropLast(2)
                if let num = Int(numStr) {
                    lastNumber = num
                    break
                }
            }
        }

        let nextNumber = lastNumber + 1
        let prefix = "\(nextNumber). "

        editorCoordinator.insertAtLineStart(prefix)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    let data = try Data(contentsOf: url)
                    let mimeType = mimeTypeForExtension(url.pathExtension)
                    let attachment = Attachment(
                        filename: url.lastPathComponent,
                        mimeType: mimeType,
                        data: data
                    )
                    emailManager.currentEmail.attachments.append(attachment)
                } catch {
                    print("Failed to read file: \(error)")
                }
            }
        case .failure(let error):
            print("File import failed: \(error)")
        }
    }

    private func mimeTypeForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "txt": return "text/plain"
        case "html", "htm": return "text/html"
        case "zip": return "application/zip"
        case "mp3": return "audio/mpeg"
        case "mp4": return "video/mp4"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Email Chip

struct EmailChip: View {
    let email: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(email)
                .font(.callout)
                .lineLimit(1)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Attachment Chip

struct AttachmentChip: View {
    let attachment: Attachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconForMimeType(attachment.mimeType))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.filename)
                    .font(.caption)
                    .lineLimit(1)
                Text(formatFileSize(attachment.data.count))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func iconForMimeType(_ mimeType: String) -> String {
        if mimeType.hasPrefix("image/") { return "photo" }
        if mimeType.hasPrefix("video/") { return "film" }
        if mimeType.hasPrefix("audio/") { return "music.note" }
        if mimeType.contains("pdf") { return "doc.text" }
        if mimeType.contains("zip") { return "doc.zipper" }
        if mimeType.contains("word") || mimeType.contains("document") { return "doc.richtext" }
        if mimeType.contains("sheet") || mimeType.contains("excel") { return "tablecells" }
        if mimeType.contains("presentation") || mimeType.contains("powerpoint") { return "rectangle.on.rectangle" }
        return "doc"
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Markdown Text Editor

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    var coordinator: TextEditorCoordinator

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        // Register with the shared coordinator
        coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView

        // Keep coordinator reference updated
        coordinator.textView = textView

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            // Try to preserve cursor position
            if selectedRange.location <= text.count {
                textView.setSelectedRange(NSRange(location: min(selectedRange.location, text.count), length: 0))
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

// MARK: - Insert Link View

struct InsertLinkView: View {
    @Binding var text: String
    @Binding var url: String
    let onInsert: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Insert Link")
                .font(.headline)

            TextField("Link text", text: $text)
                .textFieldStyle(.roundedBorder)

            TextField("URL", text: $url)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Insert") {
                    onInsert(text.isEmpty ? url : text, url)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(url.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

// MARK: - Markdown Preview View

struct MarkdownPreviewView: View {
    let markdown: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            MarkdownWebView(markdown: markdown)
        }
        .frame(width: 500, height: 400)
    }
}

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = convertMarkdownToHTML(markdown)
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func convertMarkdownToHTML(_ markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        var htmlLines: [String] = []
        var inUnorderedList = false
        var inOrderedList = false

        for line in lines {
            var processedLine = line

            // Escape HTML special characters
            processedLine = processedLine.replacingOccurrences(of: "&", with: "&amp;")
            processedLine = processedLine.replacingOccurrences(of: "<", with: "&lt;")
            processedLine = processedLine.replacingOccurrences(of: ">", with: "&gt;")

            // Bold: **text**
            processedLine = processedLine.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)

            // Italic: *text*
            processedLine = processedLine.replacingOccurrences(of: #"\*(.+?)\*"#, with: "<em>$1</em>", options: .regularExpression)

            // Code: `text`
            processedLine = processedLine.replacingOccurrences(of: #"`(.+?)`"#, with: "<code>$1</code>", options: .regularExpression)

            // Links: [text](url)
            processedLine = processedLine.replacingOccurrences(of: #"\[(.+?)\]\((.+?)\)"#, with: "<a href=\"$2\">$1</a>", options: .regularExpression)

            // Headers
            if processedLine.hasPrefix("### ") {
                processedLine = "<h3>\(String(processedLine.dropFirst(4)))</h3>"
            } else if processedLine.hasPrefix("## ") {
                processedLine = "<h2>\(String(processedLine.dropFirst(3)))</h2>"
            } else if processedLine.hasPrefix("# ") {
                processedLine = "<h1>\(String(processedLine.dropFirst(2)))</h1>"
            }
            // Unordered list: - item
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
            else if let _ = processedLine.range(of: #"^\d+\. "#, options: .regularExpression) {
                if !inOrderedList {
                    if inUnorderedList {
                        htmlLines.append("</ul>")
                        inUnorderedList = false
                    }
                    htmlLines.append("<ol>")
                    inOrderedList = true
                }
                // Remove the number prefix
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
                if processedLine.isEmpty {
                    processedLine = "<br>"
                } else {
                    processedLine = "<p>\(processedLine)</p>"
                }
            }

            htmlLines.append(processedLine)
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
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 14px; line-height: 1.6; padding: 16px; color: #333; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: Menlo, Monaco, monospace; font-size: 13px; }
        a { color: #007AFF; text-decoration: none; }
        a:hover { text-decoration: underline; }
        ul, ol { margin: 8px 0; padding-left: 24px; }
        li { margin: 4px 0; }
        h1, h2, h3 { margin: 16px 0 8px 0; }
        p { margin: 8px 0; }
        strong { font-weight: 600; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

#Preview {
    ComposeView()
        .environmentObject(AuthService.shared)
        .environmentObject(EmailManager.shared)
}
