import DeviceActivity
import FamilyControls
import Foundation

/// The DeviceActivity schedule + event set that drives the whole app.
///
/// The main app installs the plan, the monitor extension interprets the event
/// names that come back.
enum MonitoringPlan {

    /// The single daily activity from the spec (§2.2): 00:00 → 23:59, repeating.
    static let activityName = DeviceActivityName("awaretime.daily")

    /// After the shield is lifted for `snoozeMinutes`, we need a signal to put
    /// it back. DeviceActivity cannot be re-scheduled from a shield extension,
    /// so the app pre-registers a series of "re-shield" thresholds at
    /// `shieldThreshold + n × snooze`.
    static let reshieldSlots = 8

    private static let levelPrefix = "awaretime.level"
    private static let reshieldPrefix = "awaretime.reshield."

    // MARK: - Event names

    static func eventName(for level: InterventionLevel) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("\(levelPrefix)\(level.rawValue)")
    }

    static func reshieldEventName(_ index: Int) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("\(reshieldPrefix)\(index)")
    }

    enum EventKind: Equatable {
        case level(InterventionLevel)
        case reshield(index: Int)
    }

    static func kind(of name: DeviceActivityEvent.Name) -> EventKind? {
        let raw = name.rawValue
        if raw.hasPrefix(levelPrefix),
           let value = Int(raw.dropFirst(levelPrefix.count)),
           let level = InterventionLevel(rawValue: value) {
            return .level(level)
        }
        if raw.hasPrefix(reshieldPrefix),
           let index = Int(raw.dropFirst(reshieldPrefix.count)) {
            return .reshield(index: index)
        }
        return nil
    }

    /// Minutes of usage a given event represents.
    static func minutes(for kind: EventKind, settings: InterventionSettings) -> Int {
        switch kind {
        case .level(let level):
            return settings.threshold(for: level) ?? 0
        case .reshield(let index):
            return settings.shieldThresholdMinutes + settings.snoozeMinutes * index
        }
    }

    // MARK: - Schedule

    /// Minutes of advance notice before a threshold is reached. Drives
    /// `DeviceActivityMonitor.eventWillReachThresholdWarning`.
    static let warningLeadMinutes = 5

    static func schedule() -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: DateComponents(minute: warningLeadMinutes)
        )
    }

    // MARK: - Events

    static func events(
        selection: FamilyActivitySelection,
        settings: InterventionSettings
    ) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        let settings = settings.normalized()
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        func addEvent(named name: DeviceActivityEvent.Name, minutes: Int) {
            // DeviceActivity rejects a threshold that cannot be reached inside
            // the interval.
            guard minutes > 0, minutes < 24 * 60 else { return }
            events[name] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: minutes)
            )
        }

        if settings.notificationsEnabled {
            addEvent(named: eventName(for: .notice), minutes: settings.notificationThresholdMinutes)
        }
        addEvent(named: eventName(for: .warning), minutes: settings.warningThresholdMinutes)

        if settings.shieldEnabled {
            addEvent(named: eventName(for: .shield), minutes: settings.shieldThresholdMinutes)
            for index in 1...reshieldSlots {
                addEvent(
                    named: reshieldEventName(index),
                    minutes: settings.shieldThresholdMinutes + settings.snoozeMinutes * index
                )
            }
        }

        return events
    }

    /// Human readable description of the ladder, used in the dashboard.
    static func ladderDescription(settings: InterventionSettings) -> [LadderStep] {
        let settings = settings.normalized()
        return [
            LadderStep(level: .notice, minutes: settings.notificationThresholdMinutes,
                       detail: "Thông báo nhắc nhẹ"),
            LadderStep(level: .warning, minutes: settings.warningThresholdMinutes,
                       detail: "Cảnh báo + Dynamic Island đổi màu"),
            LadderStep(level: .shield, minutes: settings.shieldThresholdMinutes,
                       detail: "Hiện màn chắn, cần vượt cửa để tiếp tục")
        ]
    }
}

/// One rung of the escalation ladder, as shown in the UI.
struct LadderStep: Identifiable, Equatable {
    var level: InterventionLevel
    var minutes: Int
    var detail: String

    var id: Int { level.rawValue }
}
