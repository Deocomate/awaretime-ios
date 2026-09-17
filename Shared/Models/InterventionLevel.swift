import Foundation

/// The escalation ladder described in the spec (§2.3).
enum InterventionLevel: Int, Codable, Comparable, CaseIterable {
    case none = 0
    /// Level 1 — gentle local notification.
    case notice = 1
    /// Level 2 — amber Live Activity + time-sensitive notification.
    case warning = 2
    /// Level 3 — shield applied to the watched apps.
    case shield = 3

    static func < (lhs: InterventionLevel, rhs: InterventionLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .none: return "Bình thường"
        case .notice: return "Nhắc nhẹ"
        case .warning: return "Cảnh báo"
        case .shield: return "Đã chặn"
        }
    }

    var shortTitle: String {
        switch self {
        case .none: return "Ổn"
        case .notice: return "Mức 1"
        case .warning: return "Mức 2"
        case .shield: return "Mức 3"
        }
    }

    var symbolName: String {
        switch self {
        case .none: return "checkmark.circle.fill"
        case .notice: return "bell.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .shield: return "hand.raised.fill"
        }
    }
}
