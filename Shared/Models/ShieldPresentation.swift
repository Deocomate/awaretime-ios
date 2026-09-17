import Foundation

/// Everything the shield extensions need in order to draw and handle the
/// blocking screen.
///
/// It is written to the App Group *at the moment the shield is applied*, which
/// means `ShieldConfigurationDataSource` can render the final screen (including
/// a freshly generated maths question) without relying on the shield UI being
/// refreshed mid-session.
struct ShieldPresentation: Codable, Equatable {

    enum Mode: String, Codable {
        /// Two plain buttons: "Đóng ứng dụng" / "Tiếp tục sử dụng".
        case gate
        /// Two buttons carrying the candidate answers of `challenge`.
        case challenge
    }

    var mode: Mode
    var minutesUsed: Int
    var snoozeMinutes: Int
    var continueDelaySeconds: Int
    var challenge: MathChallenge?
    var snoozeCount: Int
    var maxSnoozesPerDay: Int
    var unlockBehavior: ShieldUnlockBehavior
    var generatedAt: Date

    var snoozeQuotaReached: Bool {
        maxSnoozesPerDay > 0 && snoozeCount >= maxSnoozesPerDay
    }

    static func make(
        minutesUsed: Int,
        settings: InterventionSettings,
        snoozeCount: Int,
        now: Date = Date()
    ) -> ShieldPresentation {
        let quotaReached = settings.maxSnoozesPerDay > 0 && snoozeCount >= settings.maxSnoozesPerDay
        let mode: Mode = (settings.requiresMathChallenge && !quotaReached) ? .challenge : .gate
        return ShieldPresentation(
            mode: mode,
            minutesUsed: minutesUsed,
            snoozeMinutes: settings.snoozeMinutes,
            continueDelaySeconds: settings.continueDelaySeconds,
            challenge: mode == .challenge ? MathChallenge.make() : nil,
            snoozeCount: snoozeCount,
            maxSnoozesPerDay: settings.maxSnoozesPerDay,
            unlockBehavior: settings.unlockBehavior,
            generatedAt: now
        )
    }

    static let placeholder = ShieldPresentation(
        mode: .gate,
        minutesUsed: 0,
        snoozeMinutes: 15,
        continueDelaySeconds: 5,
        challenge: nil,
        snoozeCount: 0,
        maxSnoozesPerDay: 0,
        unlockBehavior: .closeAndReopen,
        generatedAt: Date(timeIntervalSince1970: 0)
    )

    // MARK: - Copy shown on the shield

    var title: String {
        minutesUsed > 0 ? "Bạn đã dùng \(minutesUsed) phút" : "Đã đến lúc tạm nghỉ"
    }

    var subtitle: String {
        if snoozeQuotaReached {
            return "AwareTime đã tạm dừng ứng dụng này.\nBạn đã dùng hết \(maxSnoozesPerDay) lần gia hạn hôm nay."
        }
        switch mode {
        case .gate:
            let delay = continueDelaySeconds > 0
                ? " Bạn sẽ chờ \(continueDelaySeconds) giây trước khi mở lại."
                : ""
            return "AwareTime đã tạm dừng ứng dụng này.\nChọn “Tiếp tục sử dụng” để dùng thêm \(snoozeMinutes) phút.\(delay)"
        case .challenge:
            let question = challenge?.question ?? ""
            return "Giải nhanh để dùng thêm \(snoozeMinutes) phút:\n\(question)\nChọn sai sẽ đóng ứng dụng."
        }
    }

    var primaryButtonTitle: String {
        if snoozeQuotaReached { return "Đóng ứng dụng" }
        switch mode {
        case .gate: return "Đóng ứng dụng"
        case .challenge: return challenge?.primaryAnswer ?? "Đóng ứng dụng"
        }
    }

    /// `nil` hides the secondary button entirely (used when the daily snooze
    /// quota is exhausted).
    var secondaryButtonTitle: String? {
        if snoozeQuotaReached { return nil }
        switch mode {
        case .gate: return "Tiếp tục sử dụng"
        case .challenge: return challenge?.secondaryAnswer
        }
    }
}
