import Foundation

/// Rolling state for the current monitoring day. Lives in the App Group so the
/// monitor extension, the shield extensions and the app all agree on it.
struct DayState: Codable, Equatable {

    /// `yyyy-MM-dd` in the current calendar, used to detect a new day.
    var dayKey: String
    /// Highest level reached today.
    var level: InterventionLevel
    /// Minutes recorded by the last DeviceActivity event that fired.
    var reachedMinutes: Int
    /// True while tokens are inside the shield store.
    var shieldActive: Bool
    /// When the current unlock expires (nil when not snoozing).
    var snoozeUntil: Date?
    /// How many unlocks were granted today.
    var snoozeCount: Int
    /// Timestamp of the most recent threshold event.
    var lastEventDate: Date?

    static func empty(dayKey: String = DayState.currentDayKey()) -> DayState {
        DayState(
            dayKey: dayKey,
            level: .none,
            reachedMinutes: 0,
            shieldActive: false,
            snoozeUntil: nil,
            snoozeCount: 0,
            lastEventDate: nil
        )
    }

    var isSnoozing: Bool {
        guard let snoozeUntil else { return false }
        return snoozeUntil > Date()
    }

    var snoozeRemaining: TimeInterval {
        guard let snoozeUntil else { return 0 }
        return max(0, snoozeUntil.timeIntervalSinceNow)
    }

    static func currentDayKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Returns a fresh state when the calendar day rolled over.
    func rolledOverIfNeeded(now: Date = Date()) -> DayState {
        let key = DayState.currentDayKey(for: now)
        return key == dayKey ? self : DayState.empty(dayKey: key)
    }
}
