import SwiftUI

struct DaySelectionBar: View {
    let selectedWeekdays: Set<Int>
    let onToggle: (Int) -> Void

    private let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]
    private let pillWidth: CGFloat = 42

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                weekdayButtons
            }
            .fixedSize(horizontal: true, vertical: false)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: pillWidth, maximum: pillWidth), spacing: 6, alignment: .leading)],
                alignment: .leading,
                spacing: 6
            ) {
                weekdayButtons
            }
        }
    }

    @ViewBuilder
    private var weekdayButtons: some View {
        ForEach(weekdayOrder, id: \.self) { weekday in
            Button(shortWeekday(weekday)) {
                onToggle(weekday)
            }
            .buttonStyle(.plain)
            .font(.callout.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(width: pillWidth, height: 28)
            .contentShape(Capsule())
            .background(
                selectedWeekdays.contains(weekday) ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        selectedWeekdays.contains(weekday) ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.14),
                        lineWidth: 1
                    )
            }
        }
    }

    private func shortWeekday(_ weekday: Int) -> String {
        let symbols = Calendar.autoupdatingCurrent.shortStandaloneWeekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday - 1))
        return String(symbols[index].prefix(2))
    }
}
