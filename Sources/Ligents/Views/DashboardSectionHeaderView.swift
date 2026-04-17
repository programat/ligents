import SwiftUI

struct DashboardSectionHeaderView: View {
    let title: String
    let detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 3)
        .padding(.top, 2)
    }
}
