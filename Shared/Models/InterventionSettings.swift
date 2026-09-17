import Foundation

/// User-configurable escalation thresholds.
///
/// Decoding is defensive: every property falls back to its default when the
/// stored payload was written by an older build.
struct InterventionSettings: Codable, Equatable {

    /// Level 1 — a gentle local notification.
    var notificationThresholdMinutes: Int
    /// Level 2 — Live Activity / Dynamic Island turns amber, time-sensitive
    /// notification.
    var warningThresholdMinutes: Int
    /// Level 3 — a `ManagedSettings` shield is applied to the watched apps.
    var shieldThresholdMinutes: Int

    /// How long "Tiếp tục sử dụng" unlocks the app for.
    var snoozeMinutes: Int
    /// Mandatory wait before the shield is lifted.
    var continueDelaySeconds: Int
    /// When enabled the shield asks a small arithmetic question instead of
    /// showing a plain "Tiếp tục sử dụng" button.
    var requiresMathChallenge: Bool
    /// How many times a shield may be lifted per day (0 = unlimited).
    var maxSnoozesPerDay: Int

    var notificationsEnabled: Bool
    var liveActivityEnabled: Bool
    var shieldEnabled: Bool

    /// How the shield reacts after a successful unlock. See
    /// `ShieldUnlockBehavior`.
    var unlockBehavior: ShieldUnlockBehavior

    static let `default` = InterventionSettings(
        notificationThresholdMinutes: 15,
        warningThresholdMinutes: 30,
        shieldThresholdMinutes: 45,
        snoozeMinutes: 15,
        continueDelaySeconds: 5,
        requiresMathChallenge: false,
        maxSnoozesPerDay: 0,
        notificationsEnabled: true,
        liveActivityEnabled: true,
        shieldEnabled: true,
        unlockBehavior: .closeAndReopen
    )

    init(
        notificationThresholdMinutes: Int = 15,
        warningThresholdMinutes: Int = 30,
        shieldThresholdMinutes: Int = 45,
        snoozeMinutes: Int = 15,
        continueDelaySeconds: Int = 5,
        requiresMathChallenge: Bool = false,
        maxSnoozesPerDay: Int = 0,
        notificationsEnabled: Bool = true,
        liveActivityEnabled: Bool = true,
        shieldEnabled: Bool = true,
        unlockBehavior: ShieldUnlockBehavior = .closeAndReopen
    ) {
        self.notificationThresholdMinutes = notificationThresholdMinutes
        self.warningThresholdMinutes = warningThresholdMinutes
        self.shieldThresholdMinutes = shieldThresholdMinutes
        self.snoozeMinutes = snoozeMinutes
        self.continueDelaySeconds = continueDelaySeconds
        self.requiresMathChallenge = requiresMathChallenge
        self.maxSnoozesPerDay = maxSnoozesPerDay
        self.notificationsEnabled = notificationsEnabled
        self.liveActivityEnabled = liveActivityEnabled
        self.shieldEnabled = shieldEnabled
        self.unlockBehavior = unlockBehavior
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = InterventionSettings.default
        notificationThresholdMinutes = try c.decodeIfPresent(Int.self, forKey: .notificationThresholdMinutes)
            ?? d.notificationThresholdMinutes
        warningThresholdMinutes = try c.decodeIfPresent(Int.self, forKey: .warningThresholdMinutes)
            ?? d.warningThresholdMinutes
        shieldThresholdMinutes = try c.decodeIfPresent(Int.self, forKey: .shieldThresholdMinutes)
            ?? d.shieldThresholdMinutes
        snoozeMinutes = try c.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? d.snoozeMinutes
        continueDelaySeconds = try c.decodeIfPresent(Int.self, forKey: .continueDelaySeconds)
            ?? d.continueDelaySeconds
        requiresMathChallenge = try c.decodeIfPresent(Bool.self, forKey: .requiresMathChallenge)
            ?? d.requiresMathChallenge
        maxSnoozesPerDay = try c.decodeIfPresent(Int.self, forKey: .maxSnoozesPerDay) ?? d.maxSnoozesPerDay
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled)
            ?? d.notificationsEnabled
        liveActivityEnabled = try c.decodeIfPresent(Bool.self, forKey: .liveActivityEnabled)
            ?? d.liveActivityEnabled
        shieldEnabled = try c.decodeIfPresent(Bool.self, forKey: .shieldEnabled) ?? d.shieldEnabled
        unlockBehavior = try c.decodeIfPresent(ShieldUnlockBehavior.self, forKey: .unlockBehavior)
            ?? d.unlockBehavior
    }

    // MARK: - Validation

    static let allowedThresholds: [Int] = [1, 2, 5, 10, 15, 20, 25, 30, 40, 45, 50, 60, 75, 90, 120, 150, 180]
    static let allowedSnoozes: [Int] = [5, 10, 15, 20, 30, 45, 60]
    static let allowedDelays: [Int] = [0, 3, 5, 10, 15, 20, 30]

    /// Keeps the three levels strictly increasing so that DeviceActivity does
    /// not receive two events with the same threshold.
    func normalized() -> InterventionSettings {
        var copy = self
        copy.notificationThresholdMinutes = max(1, notificationThresholdMinutes)
        copy.warningThresholdMinutes = max(copy.notificationThresholdMinutes + 1, warningThresholdMinutes)
        copy.shieldThresholdMinutes = max(copy.warningThresholdMinutes + 1, shieldThresholdMinutes)
        copy.snoozeMinutes = min(max(1, snoozeMinutes), 240)
        copy.continueDelaySeconds = min(max(0, continueDelaySeconds), 30)
        copy.maxSnoozesPerDay = max(0, maxSnoozesPerDay)
        return copy
    }

    func threshold(for level: InterventionLevel) -> Int? {
        switch level {
        case .none: return nil
        case .notice: return notificationThresholdMinutes
        case .warning: return warningThresholdMinutes
        case .shield: return shieldThresholdMinutes
        }
    }
}

/// What happens after the user solves the gate on the shield screen.
///
/// `ManagedSettings` gives no documented guarantee that dismissing the shield
/// in place works on every iOS release, so the reliable behaviour is the
/// default and the in-place dismissal is opt-in.
enum ShieldUnlockBehavior: String, Codable, CaseIterable, Identifiable {
    /// Remove the shield, then close the app. Re-opening it works normally.
    case closeAndReopen
    /// Remove the shield and try to dismiss the shield screen in place.
    case dismissShield

    var id: String { rawValue }

    var title: String {
        switch self {
        case .closeAndReopen: return "Đóng rồi mở lại (ổn định)"
        case .dismissShield: return "Ẩn màn chắn ngay"
        }
    }

    var explanation: String {
        switch self {
        case .closeAndReopen:
            return "Màn chắn được gỡ và ứng dụng đóng lại. Mở lại ứng dụng là dùng được ngay — cách này hoạt động trên mọi phiên bản iOS."
        case .dismissShield:
            return "Thử ẩn màn chắn và quay lại ứng dụng ngay lập tức. Nhanh hơn nhưng có thể không hoạt động trên một số phiên bản iOS."
        }
    }
}
