import Foundation

enum DisplayFormatters {
    static func resetLabel(for date: Date?) -> String {
        guard let date else {
            return "unknown"
        }

        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM HH:mm")
        return formatter.string(from: date)
    }

    static func syncAgeLabel(for date: Date?) -> String {
        guard let date else {
            return "never"
        }

        if abs(date.timeIntervalSinceNow) < 60 {
            return "just now"
        }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        return relative.localizedString(for: date, relativeTo: .now)
    }

    static func syncTimestampLabel(for date: Date?) -> String {
        guard let date else {
            return "Never synced"
        }

        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.setLocalizedDateFormatFromTemplate("d MMM HH:mm")
        return formatter.string(from: date)
    }

    static func timeLabel(minutesAfterMidnight: Int) -> String {
        let safeMinutes = min(max(minutesAfterMidnight, 0), (24 * 60) - 1)
        let date = Calendar.autoupdatingCurrent.startOfDay(for: .now)
            .addingTimeInterval(TimeInterval(safeMinutes * 60))

        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter.string(from: date)
    }
}
