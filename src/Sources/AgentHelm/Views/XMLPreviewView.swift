import SwiftUI

struct XMLPreviewView: View {
    let raw: String

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(prettyPrinted ?? raw)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
    }

    private var prettyPrinted: String? {
        guard let data = raw.data(using: .utf8) else { return nil }
        do {
            let doc = try XMLDocument(data: data, options: [.documentTidyXML])
            doc.characterEncoding = "UTF-8"
            let formatted = doc.xmlData(options: [.nodePrettyPrint, .nodeCompactEmptyElement])
            return String(data: formatted, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
