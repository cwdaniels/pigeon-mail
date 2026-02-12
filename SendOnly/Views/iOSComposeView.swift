#if os(iOS)
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import WebKit

struct iOSComposeView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var emailManager: EmailManager
    @StateObject private var draftManager = DraftManager.shared
    @StateObject private var favoritesManager = FavoritesManager.shared

    @State private var toField = ""
    @State private var ccField = ""
    @State private var bccField = ""
    @State private var showCC = false
    @State private var showBCC = false

    @State private var showSchedulePicker = false
    @State private var showFilePicker = false
    @State private var showMarkdownPreview = false
    @State private var showLinkSheet = false
    @State private var showDraftsDrawer = false
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
        NavigationStack {
            Form {
                // Favorites bar
                if favoritesManager.showFavoritesBar {
                    let topFavorites = favoritesManager.getTopFavorites(limit: 5)
                    if !topFavorites.isEmpty {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(topFavorites) { favorite in
                                        Button {
                                            addFavoriteToRecipients(favorite)
                                        } label: {
                                            HStack(spacing: 4) {
                                                if favorite.isPinned {
                                                    Image(systemName: "pin.fill")
                                                        .font(.caption2)
                                                        .foregroundColor(.orange)
                                                }
                                                Text(favorite.displayName)
                                                    .font(.callout)
                                                    .lineLimit(1)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.accentColor.opacity(0.15))
                                            .cornerRadius(14)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }

                // Recipients
                Section {
                    recipientField(label: "To", text: $toField, field: .to, emails: $emailManager.currentEmail.to)

                    if showCC {
                        recipientField(label: "Cc", text: $ccField, field: .cc, emails: $emailManager.currentEmail.cc)
                    }

                    if showBCC {
                        recipientField(label: "Bcc", text: $bccField, field: .bcc, emails: $emailManager.currentEmail.bcc)
                    }

                    TextField("Subject", text: $emailManager.currentEmail.subject)
                }

                // Contact suggestions
                if !contactSuggestions.isEmpty {
                    Section("Suggestions") {
                        ForEach(contactSuggestions) { contact in
                            Button {
                                selectContact(contact)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(contact.displayName)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text(contact.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Body
                Section {
                    TextEditor(text: $emailManager.currentEmail.body)
                        .frame(minHeight: 200)
                }

                // Attachments
                if !emailManager.currentEmail.attachments.isEmpty {
                    Section("Attachments") {
                        ForEach(emailManager.currentEmail.attachments) { attachment in
                            HStack {
                                AttachmentChip(attachment: attachment) {
                                    emailManager.currentEmail.attachments.removeAll { $0.id == attachment.id }
                                }
                                Spacer()
                            }
                        }
                    }
                }

                // From
                Section {
                    HStack {
                        Text("From")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(authService.formattedFromAddress)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel / Discard menu
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Save Draft", role: nil) {
                            dismiss()
                        }
                        Button("Discard", role: .destructive) {
                            discardDraft()
                        }
                    } label: {
                        Text("Cancel")
                    }
                }

                // Send button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if emailManager.sendEmail() {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(!emailManager.currentEmail.hasRecipients)
                }

                // Overflow menu
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showCC.toggle()
                        } label: {
                            Label(showCC ? "Hide Cc" : "Show Cc", systemImage: "person.2")
                        }

                        Button {
                            showBCC.toggle()
                        } label: {
                            Label(showBCC ? "Hide Bcc" : "Show Bcc", systemImage: "person.2.fill")
                        }

                        Divider()

                        Button {
                            showFilePicker = true
                        } label: {
                            Label("Attach File", systemImage: "paperclip")
                        }

                        Button {
                            showSchedulePicker = true
                        } label: {
                            Label("Schedule Send", systemImage: "clock")
                        }

                        Button {
                            showMarkdownPreview = true
                        } label: {
                            Label("Preview", systemImage: "eye")
                        }

                        Button {
                            showDraftsDrawer = true
                        } label: {
                            Label("Load Draft", systemImage: "doc.text")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                // Keyboard toolbar for formatting
                ToolbarItemGroup(placement: .keyboard) {
                    Button {
                        insertFormatting(prefix: "**", suffix: "**")
                    } label: {
                        Image(systemName: "bold")
                    }

                    Button {
                        insertFormatting(prefix: "*", suffix: "*")
                    } label: {
                        Image(systemName: "italic")
                    }

                    Button {
                        insertFormatting(prefix: "`", suffix: "`")
                    } label: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                    }

                    Spacer()

                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
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
                iOSMarkdownPreviewView(markdown: emailManager.currentEmail.body)
            }
            .sheet(isPresented: $showLinkSheet) {
                InsertLinkView(text: $linkText, url: $linkURL) { text, url in
                    let linkMarkdown = "[\(text)](\(url))"
                    emailManager.currentEmail.body += linkMarkdown
                    linkText = ""
                    linkURL = ""
                }
            }
            .sheet(isPresented: $showDraftsDrawer) {
                NavigationStack {
                    iOSDraftsListView { draft in
                        loadDraftIntoCompose(draft)
                        showDraftsDrawer = false
                    }
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
    }

    // MARK: - Recipient Field

    private func recipientField(label: String, text: Binding<String>, field: RecipientField, emails: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !emails.wrappedValue.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(emails.wrappedValue, id: \.self) { email in
                        EmailChip(email: email) {
                            emails.wrappedValue.removeAll { $0 == email }
                        }
                    }
                }
            }

            TextField(label, text: text)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .onSubmit {
                    addEmailFromField(text: text, emails: emails)
                }
                .onChange(of: text.wrappedValue) { _, _ in
                    activeField = field
                }
        }
    }

    // MARK: - Actions

    private func handleRecipientFieldChange(_ value: String, field: RecipientField) {
        activeField = field

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

    private func addFavoriteToRecipients(_ favorite: FavoriteContact) {
        guard !emailManager.currentEmail.to.contains(where: { $0.lowercased() == favorite.email.lowercased() }) else {
            return
        }
        emailManager.currentEmail.to.append(favorite.email)
    }

    private func loadDraftIntoCompose(_ draft: DraftSummary) {
        Task {
            if let email = await draftManager.loadDraft(draft.id) {
                emailManager.currentEmail = email
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return email.range(of: emailRegex, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func insertFormatting(prefix: String, suffix: String) {
        emailManager.currentEmail.body += "\(prefix)text\(suffix)"
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

// MARK: - iOS Markdown Preview

struct iOSMarkdownPreviewView: View {
    let markdown: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            iOSMarkdownWebView(markdown: markdown)
                .navigationTitle("Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct iOSMarkdownWebView: UIViewRepresentable {
    let markdown: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let email = Email()
        let html = email.markdownToHTML(markdown)
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - iOS Drafts List

struct iOSDraftsListView: View {
    @StateObject private var draftManager = DraftManager.shared
    let onSelectDraft: (DraftSummary) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if draftManager.isLoadingDrafts {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading drafts...")
                        .foregroundColor(.secondary)
                }
            } else if draftManager.drafts.isEmpty {
                Text("No drafts")
                    .foregroundColor(.secondary)
            } else {
                ForEach(draftManager.drafts) { draft in
                    Button {
                        onSelectDraft(draft)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.to)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(draft.subject)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            if !draft.snippet.isEmpty {
                                Text(draft.snippet)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Drafts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await draftManager.fetchDrafts()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(draftManager.isLoadingDrafts)
            }
        }
        .task {
            if draftManager.drafts.isEmpty {
                await draftManager.fetchDrafts()
            }
        }
    }
}
#endif
