import Foundation

/// One entry in the shared activity log. Written by the monitor and shield
/// extensions, read by the dashboard.
struct InterventionEvent: Codable, Identifiable, Equatable {

    enum Kind: String, Codable {
        case monitoringStarted
        case monitoringStopped
        case intervalStarted
        case intervalEnded
        case noticeReached
        case warningReached
        case shieldApplied
        case shieldReapplied
        case shieldLifted
        case shieldClosedApp
        case challengeFailed
        case snoozeDenied

        var symbolName: String {
            switch self {
            case .monitoringStarted: return "play.circle.fill"
            case .monitoringStopped: return "stop.circle.fill"
            case .intervalStarted: return "sunrise.fill"
            case .intervalEnded: return "moon.stars.fill"
            case .noticeReached: return "bell.fill"
            case .warningReached: return "exclamationmark.triangle.fill"
            case .shieldApplied, .shieldReapplied: return "hand.raised.fill"
            case .shieldLifted: return "lock.open.fill"
            case .shieldClosedApp: return "xmark.circle.fill"
            case .challengeFailed: return "questionmark.circle.fill"
            case .snoozeDenied: return "nosign"
            }
        }

        var isAlert: Bool {
            switch self {
            case .warningReached, .shieldApplied, .shieldReapplied, .challengeFailed, .snoozeDenied:
                return true
            default:
                return false
            }
        }
    }

    var id: UUID
    var date: Date
    var kind: Kind
    var message: String
    var minutes: Int?

    init(id: UUID = UUID(), date: Date = Date(), kind: Kind, message: String, minutes: Int? = nil) {
        self.id = id
        self.date = date
        self.kind = kind
        self.message = message
        self.minutes = minutes
    }
}
