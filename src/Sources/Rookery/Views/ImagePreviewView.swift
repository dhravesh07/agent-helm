import SwiftUI
import AppKit

struct ImagePreviewView: View {
    let data: Data

    var body: some View {
        if let nsImage = NSImage(data: data) {
            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
            }
            .background(Color(nsColor: .underPageBackgroundColor))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                Text("Image format not supported")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
