import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Payload for the Lock Screen widget / Dynamic Island (spec §3.4).
@available(iOS 16.1, *)
struct AwareTimeActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {
        var level: InterventionLevel
        /// Minutes recorded by the most recent DeviceActivity threshold.
        var minutesUsed: Int
        /// Minute mark at which the shield kicks in.
        var shieldAtMinutes: Int
        var shieldActive: Bool
        var snoozeUntil: Date?
        var updatedAt: Date

        static func snapshot(
            dayState: DayState,
            settings: InterventionSettings,
            now: Date = Date()
        ) -> ContentState {
            ContentState(
                level: dayState.level,
                minutesUsed: dayState.reachedMinutes,
                shieldAtMinutes: settings.shieldThresholdMinutes,
                shieldActive: dayState.shieldActive,
                snoozeUntil: dayState.snoozeUntil,
                updatedAt: now
            )
        }

        /// 0…1 progress towards the shield threshold.
        var progress: Double {
            guard shieldAtMinutes > 0 else { return 0 }
            return min(1, Double(minutesUsed) / Double(shieldAtMinutes))
        }

        var headline: String {
            switch level {
            case .none: return "Đang theo dõi"
            case .notice: return "Đã dùng \(minutesUsed) phút"
            case .warning: return "Cảnh báo · \(minutesUsed) phút"
            case .shield: return shieldActive ? "Đã chặn · \(minutesUsed) phút" : "Gia hạn · \(minutesUsed) phút"
            }
        }

        var detail: String {
            if let snoozeUntil, snoozeUntil > updatedAt {
                return "Gia hạn đến \(AwareTimeFormat.clock(snoozeUntil))"
            }
            switch level {
            case .none, .notice:
                let remaining = max(0, shieldAtMinutes - minutesUsed)
                return remaining > 0 ? "Còn \(remaining) phút trước khi chặn" : "Sắp chạm mốc chặn"
            case .warning:
                let remaining = max(0, shieldAtMinutes - minutesUsed)
                return remaining > 0 ? "Chặn sau \(remaining) phút" : "Sắp bị chặn"
            case .shield:
                return "Mở AwareTime để xử lý"
            }
        }
    }

    /// How many apps / categories / sites are being watched.
    var watchedCount: Int
    var startedAt: Date
}
#endif
