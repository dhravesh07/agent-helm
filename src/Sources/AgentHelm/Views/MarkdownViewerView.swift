import SwiftUI

struct MarkdownViewerView: View {
    let entry: RemoteFileEntry?
    let contents: String?

    var body: some View {
        if let entry {
            VStack(alignment: .leading, spacing: 0) {
                headerBar(entry: entry)
                Divider()
                ScrollView {
                    body(for: entry)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            }
        } else {
            placeholder
        }
    }

    private func headerBar(entry: RemoteFileEntry) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(entry.name)
                .font(.title3.bold())
            Spacer()
            Text(entry.path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func body(for entry: RemoteFileEntry) -> some View {
        if entry.isDirectory {
            Text("Folder selected. Open a file to view its contents.")
                .foregroundStyle(.secondary)
        } else if let contents {
            if entry.isMarkdown {
                renderedMarkdown(contents)
            } else {
                Text(contents)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        } else {
            ProgressView().controlSize(.small)
        }
    }

    private func renderedMarkdown(_ raw: String) -> some View {
        let attributed = (try? AttributedString(
            markdown: raw,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(raw)
        return Text(attributed)
            .textSelection(.enabled)
            .font(.body)
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("Select a file to view")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
