import SwiftUI

struct CopyEmailButton: View {
    let email: String?

    var body: some View {
        if let email, !email.isEmpty {
            Button {
                PasteboardWriter.copy(email)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Copy \(email)")
            .accessibilityLabel("Copy email")
        }
    }
}
