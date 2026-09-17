import Foundation
import UserNotifications

/// Local notifications for the escalation ladder.
///
/// Called from the main app (permission + test notification) and from the
/// DeviceActivity monitor extension (level 1/2/3 alerts).
enum NotificationScheduler {

    enum Identifier {
        static let notice = "awaretime.notice"
        static let warning = "awaretime.warning"
        static let shield = "awaretime.shield"
        static let snoozeExpired = "awaretime.snoozeExpired"
        static let dayReset = "awaretime.dayReset"
        static let test = "awaretime.test"
    }

    // MARK: - Authorization

    static func requestAuthorization() async -> Bool {
        do {
            // Time-sensitive delivery comes from the
            // `com.apple.developer.usernotifications.time-sensitive`
            // entitlement; the matching request option is deprecated.
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Posting

    /// Fire-and-forget delivery. Safe to call from an app extension.
    static func post(
        identifier: String,
        title: String,
        body: String,
        interruptionLevel: UNNotificationInterruptionLevel = .active,
        relevanceScore: Double = 0.5
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = interruptionLevel
        content.relevanceScore = relevanceScore

        let request = UNNotificationRequest(
            // A per-delivery suffix avoids silently replacing an alert the
            // user has not seen yet.
            identifier: "\(identifier).\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Ladder

    static func postNotice(minutes: Int) {
        post(
            identifier: Identifier.notice,
            title: "Bạn đã dùng \(minutes) phút",
            body: "Một nhắc nhở nhẹ từ AwareTime. Bạn vẫn đang kiểm soát tốt — để ý thêm chút nhé.",
            interruptionLevel: .active,
            relevanceScore: 0.4
        )
    }

    static func postWarning(minutes: Int, shieldAtMinutes: Int) {
        let remaining = max(0, shieldAtMinutes - minutes)
        post(
            identifier: Identifier.warning,
            title: "⚠️ Đã \(minutes) phút rồi",
            body: remaining > 0
                ? "AwareTime sẽ tạm chặn ứng dụng sau \(remaining) phút nữa. Cân nhắc dừng lại bây giờ."
                : "AwareTime sắp tạm chặn ứng dụng này.",
            interruptionLevel: .timeSensitive,
            relevanceScore: 0.8
        )
    }

    static func postShieldApplied(minutes: Int, snoozeMinutes: Int) {
        post(
            identifier: Identifier.shield,
            title: "🛑 AwareTime đã tạm chặn",
            body: "Bạn đã dùng \(minutes) phút hôm nay. Mở ứng dụng để chọn “Đóng” hoặc gia hạn \(snoozeMinutes) phút.",
            interruptionLevel: .timeSensitive,
            relevanceScore: 1.0
        )
    }

    static func postSnoozeExpired() {
        post(
            identifier: Identifier.snoozeExpired,
            title: "Hết thời gian gia hạn",
            body: "AwareTime đã bật lại màn chắn cho các ứng dụng bạn theo dõi.",
            interruptionLevel: .timeSensitive,
            relevanceScore: 0.9
        )
    }

    static func postDayReset() {
        post(
            identifier: Identifier.dayReset,
            title: "Ngày mới, bắt đầu lại nhé",
            body: "AwareTime đã đặt lại bộ đếm cho hôm nay.",
            interruptionLevel: .passive,
            relevanceScore: 0.1
        )
    }

    static func postTest() {
        post(
            identifier: Identifier.test,
            title: "AwareTime đã sẵn sàng",
            body: "Đây là thông báo thử. Cảnh báo thật sẽ xuất hiện khi bạn chạm mốc thời gian đã đặt.",
            interruptionLevel: .active
        )
    }
}
