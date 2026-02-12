#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Extract shared content
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            close()
            return
        }

        var sharedText = ""
        var sharedURL = ""
        let group = DispatchGroup()

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                        if let url = item as? URL {
                            sharedURL = url.absoluteString
                        }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                        if let text = item as? String {
                            sharedText = text
                        }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.presentComposeUI(text: sharedText, url: sharedURL)
        }
    }

    private func presentComposeUI(text: String, url: String) {
        let body = url.isEmpty ? text : (text.isEmpty ? url : "\(text)\n\(url)")

        let composeView = ShareComposeView(
            initialBody: body,
            onSend: { [weak self] to, subject, body in
                self?.sendEmail(to: to, subject: subject, body: body)
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )

        let hostingController = UIHostingController(rootView: composeView)
        hostingController.modalPresentationStyle = .fullScreen

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    private func sendEmail(to: String, subject: String, body: String) {
        // Load tokens from shared keychain
        let keychain = KeychainService.shared

        guard let tokens = try? keychain.loadTokens() else {
            showError("Not signed in. Please open Pigeon Mail and sign in first.")
            return
        }

        let email = Email(
            to: to.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) },
            subject: subject,
            body: body
        )

        // Create a standalone GmailService call
        Task {
            do {
                let gmailService = GmailService.shared
                _ = try await gmailService.sendEmail(email)

                await MainActor.run {
                    self.close()
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to send: \(error.localizedDescription)")
                }
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.close()
        })
        present(alert, animated: true)
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

// MARK: - Share Compose View

struct ShareComposeView: View {
    let initialBody: String
    let onSend: (String, String, String) -> Void
    let onCancel: () -> Void

    @State private var to = ""
    @State private var subject = ""
    @State private var emailBody = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("To", text: $to)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    TextField("Subject", text: $subject)
                }

                Section {
                    TextEditor(text: $emailBody)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("Pigeon Mail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onSend(to, subject, emailBody)
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(to.isEmpty)
                }
            }
            .onAppear {
                emailBody = initialBody
            }
        }
    }
}
#endif
