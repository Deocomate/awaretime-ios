import ActivityKit
import DeviceActivity
import Foundation
import ManagedSettings
import UserNotifications

/// Runs out-of-process whenever one of AwareTime's usage thresholds is hit
/// (spec §3.2).
///
/// This extension has a very small memory budget, so the work is deliberately
/// flat: read shared state, apply a `ManagedSettings` shield, post a
/// notification, best-effort refresh of the Live Activity.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    // MARK: - Interval

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == MonitoringPlan.activityName else { return }

        SharedStore.resetDayState()
        ShieldController.removeShield()
        SharedStore.log(.intervalStarted, "Bắt đầu ngày theo dõi mới.")
        refreshLiveActivity()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == MonitoringPlan.activityName else { return }

        ShieldController.removeShield()
        SharedStore.mutateDayState { state in
            state.shieldActive = false
            state.snoozeUntil = nil
        }
        SharedStore.log(.intervalEnded, "Kết thúc ngày theo dõi, đã gỡ mọi màn chắn.")
        refreshLiveActivity()
    }

    // MARK: - Thresholds

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == MonitoringPlan.activityName,
              let kind = MonitoringPlan.kind(of: event) else { return }

        let settings = SharedStore.settings.normalized()
        let minutes = MonitoringPlan.minutes(for: kind, settings: settings)

        switch kind {
        case .level(.notice):
            handleNotice(minutes: minutes, settings: settings)
        case .level(.warning):
            handleWarning(minutes: minutes, settings: settings)
        case .level(.shield):
            handleShield(minutes: minutes, settings: settings)
        case .level(.none):
            break
        case .reshield:
            handleReshield(minutes: minutes, settings: settings)
        }

        refreshLiveActivity()
    }

    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        guard activity == MonitoringPlan.activityName,
              MonitoringPlan.kind(of: event) == .level(.shield) else { return }

        let settings = SharedStore.settings.normalized()
        guard settings.notificationsEnabled else { return }
        NotificationScheduler.post(
            identifier: NotificationScheduler.Identifier.warning,
            title: "Sắp bị chặn",
            body: "Bạn gần chạm mốc \(settings.shieldThresholdMinutes) phút. Cân nhắc dừng lại.",
            interruptionLevel: .timeSensitive,
            relevanceScore: 0.9
        )
    }

    // MARK: - Level handlers

    private func handleNotice(minutes: Int, settings: InterventionSettings) {
        SharedStore.mutateDayState { state in
            state.level = max(state.level, .notice)
            state.reachedMinutes = max(state.reachedMinutes, minutes)
            state.lastEventDate = Date()
        }
        SharedStore.log(.noticeReached, "Mức 1 — đã dùng \(minutes) phút.", minutes: minutes)

        guard settings.notificationsEnabled else { return }
        NotificationScheduler.postNotice(minutes: minutes)
    }

    private func handleWarning(minutes: Int, settings: InterventionSettings) {
        SharedStore.mutateDayState { state in
            state.level = max(state.level, .warning)
            state.reachedMinutes = max(state.reachedMinutes, minutes)
            state.lastEventDate = Date()
        }
        SharedStore.log(.warningReached, "Mức 2 — đã dùng \(minutes) phút.", minutes: minutes)

        guard settings.notificationsEnabled else { return }
        NotificationScheduler.postWarning(
            minutes: minutes,
            shieldAtMinutes: settings.shieldThresholdMinutes
        )
    }

    private func handleShield(minutes: Int, settings: InterventionSettings) {
        guard settings.shieldEnabled else {
            SharedStore.mutateDayState { state in
                state.level = max(state.level, .shield)
                state.reachedMinutes = max(state.reachedMinutes, minutes)
                state.lastEventDate = Date()
            }
            SharedStore.log(
                .shieldApplied,
                "Mức 3 — đã dùng \(minutes) phút (màn chắn đang tắt trong cài đặt).",
                minutes: minutes
            )
            return
        }

        ShieldController.escalateToShield(minutesUsed: minutes, settings: settings)
        SharedStore.log(.shieldApplied, "Mức 3 — đã chặn sau \(minutes) phút.", minutes: minutes)

        guard settings.notificationsEnabled else { return }
        NotificationScheduler.postShieldApplied(
            minutes: minutes,
            snoozeMinutes: settings.snoozeMinutes
        )
    }

    /// Fires at `shieldThreshold + n × snooze`. If the user is still inside a
    /// granted snooze we leave them alone; otherwise the shield goes back up.
    private func handleReshield(minutes: Int, settings: InterventionSettings) {
        SharedStore.mutateDayState { state in
            state.reachedMinutes = max(state.reachedMinutes, minutes)
            state.lastEventDate = Date()
        }

        guard settings.shieldEnabled else { return }
        let didReapply = ShieldController.reapplyIfSnoozeExpired(settings: settings)
        guard didReapply else { return }

        SharedStore.log(
            .shieldReapplied,
            "Hết gia hạn — bật lại màn chắn ở mốc \(minutes) phút.",
            minutes: minutes
        )
        if settings.notificationsEnabled {
            NotificationScheduler.postSnoozeExpired()
        }
    }

    // MARK: - Live Activity

    private func refreshLiveActivity() {
        guard SharedStore.settings.liveActivityEnabled else { return }
        if #available(iOS 16.1, *) {
            let state = AwareTimeActivityAttributes.ContentState.snapshot(
                dayState: SharedStore.dayState,
                settings: SharedStore.settings
            )
            LiveActivityController.updateBlocking(state: state)
        }
    }
}
