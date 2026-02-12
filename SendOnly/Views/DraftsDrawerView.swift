import SwiftUI

struct DraftsDrawerView: View {
    @StateObject private var draftManager = DraftManager.shared
    let onSelectDraft: (DraftSummary) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Drafts")
                    .font(.headline)

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Drafts list
            if draftManager.isLoadingDrafts {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading drafts...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if draftManager.drafts.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No drafts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(draftManager.drafts) { draft in
                            DraftRowView(draft: draft) {
                                onSelectDraft(draft)
                            }

                            if draft.id != draftManager.drafts.last?.id {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
            }

            Divider()

            // Footer with refresh button
            HStack {
                Button {
                    Task {
                        await draftManager.fetchDrafts()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .disabled(draftManager.isLoadingDrafts)

                Spacer()

                Text("\(draftManager.drafts.count) drafts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        #if os(macOS)
        .frame(width: 250)
        #endif
        .background(Color.platformWindowBackground)
        .task {
            // Only fetch if we don't have cached drafts
            if draftManager.drafts.isEmpty {
                await draftManager.fetchDrafts()
            }
        }
    }
}

struct DraftRowView: View {
    let draft: DraftSummary
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                // Recipient
                Text(draft.to)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)

                // Subject
                Text(draft.subject)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // Snippet
                if !draft.snippet.isEmpty {
                    Text(draft.snippet)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

#Preview {
    DraftsDrawerView(
        onSelectDraft: { _ in },
        onClose: {}
    )
}
