import Combine
import FamilyControls
import Foundation

/// An accelerated, in-app rehearsal of the escalation ladder.
///
/// Screen Time thresholds can take 15–45 real minutes to trigger, and the
/// Family Controls entitlement is not available in every build (Simulator,
/// re-signed IPAs). Demo mode replays the exact same state transitions,
/// notifications and Live Activity updates on a fast clock so the behaviour
/// can be verified in under a minute.
@MainActor
final class DemoModeController: ObservableObject {

    @Published private(set) var isRunning = false
    @Published private(set) var simulatedMinutes = 0
    @Published private(set) var reachedLevel: InterventionLevel = .none

    /// Real seconds per simulated minute.
    @Published var secondsPerSimulatedMinute: Double = 0.4

    private var timer: Timer?
    private var settings: InterventionSettings = .default
    private var watchedCount = 0

    var isShieldStageReached: Bool { reachedLevel >= .shield }

    func start(settings: InterventionSettings, watchedCount: Int) {
        stop(resetState: true)

        self.settings = settings.normalized()
        self.watchedCount = watchedCount
        isRunning = true
        simulatedMinutes = 0
        reachedLevel = .none

        SharedStore.log(.monitoringStarted, "Bắt đầu chạy thử chế độ mô phỏng.")

        let timer = Timer(timeInterval: secondsPerSimulatedMinute, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop(resetState: Bool = false) {
        timer?.invalidate()
        timer = nil
        isRunning = false

        if resetState {
            simulatedMinutes = 0
            reachedLevel = .none
        }
    }

    /// Ends the rehearsal and puts the shared state back to a clean slate.
    func reset() {
        stop(resetState: true)
        ShieldController.removeShield()
        SharedStore.resetDayState()
        SharedStore.shieldPresentation = .placeholder
        SharedStore.log(.monitoringStopped, "Kết thúc mô phỏng, đã xoá trạng thái thử.")
        refreshLiveActivity()
    }

    // MARK: - Clock

    private func tick() {
        simulatedMinutes += 1
        let minutes = simulatedMinutes

        SharedStore.mutateDayState { state in
            state.reachedMinutes = max(state.reachedMinutes, minutes)
            state.lastEventDate = Date()
        }

        if minutes == settings.notificationThresholdMinutes {
            escalate(to: .notice, minutes: minutes)
        } else if minutes == settings.warningThresholdMinutes {
            escalate(to: .warning, minutes: minutes)
        } else if minutes == settings.shieldThresholdMinutes {
            escalate(to: .shield, minutes: minutes)
        }

        refreshLiveActivity()

        if minutes >= settings.shieldThresholdMinutes {
            stop()
        }
    }

    private func escalate(to level: InterventionLevel, minutes: Int) {
        reachedLevel = max(reachedLevel, level)

        switch level {
        case .notice:
            SharedStore.mutateDayState { $0.level = max($0.level, .notice) }
            SharedStore.log(.noticeReached, "[Mô phỏng] Mức 1 ở \(minutes) phút.", minutes: minutes)
            if settings.notificationsEnabled { NotificationScheduler.postNotice(minutes: minutes) }

        case .warning:
            SharedStore.mutateDayState { $0.level = max($0.level, .warning) }
            SharedStore.log(.warningReached, "[Mô phỏng] Mức 2 ở \(minutes) phút.", minutes: minutes)
            if settings.notificationsEnabled {
                NotificationScheduler.postWarning(
                    minutes: minutes,
                    shieldAtMinutes: settings.shieldThresholdMinutes
                )
            }

        case .shield:
            // Also stages the real shield presentation, so the preview inside
            // the app matches what the extension would draw.
            ShieldController.escalateToShield(minutesUsed: minutes, settings: settings)
            SharedStore.log(.shieldApplied, "[Mô phỏng] Mức 3 ở \(minutes) phút.", minutes: minutes)
            if settings.notificationsEnabled {
                NotificationScheduler.postShieldApplied(
                    minutes: minutes,
                    snoozeMinutes: settings.snoozeMinutes
                )
            }

        case .none:
            break
        }
    }

    private func refreshLiveActivity() {
        guard settings.liveActivityEnabled else { return }
        if #available(iOS 16.1, *) {
            let state = AwareTimeActivityAttributes.ContentState.snapshot(
                dayState: SharedStore.dayState,
                settings: settings
            )
            if LiveActivityController.isRunning {
                Task { await LiveActivityController.update(state: state) }
            } else {
                LiveActivityController.start(watchedCount: max(1, watchedCount), state: state)
            }
        }
    }
}
