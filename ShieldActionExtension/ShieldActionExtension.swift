import ActivityKit
import Foundation
import ManagedSettings

/// Handles the two buttons on the shield screen (spec §2.4 / §3.3).
///
/// * Gate mode — "Đóng ứng dụng" closes it, "Tiếp tục sử dụng" waits out the
///   configured delay and then lifts the shield for `snoozeMinutes`.
/// * Challenge mode — the two buttons are the candidate answers to a small
///   arithmetic question. A wrong answer closes the app and a brand new
///   question is staged for the next attempt.
final class ShieldActionExtension: ShieldActionDelegate {

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        resolve(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        resolve(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        resolve(action: action, completionHandler: completionHandler)
    }

    // MARK: - Decision

    private func resolve(
        action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let settings = SharedStore.settings.normalized()
        let presentation = SharedStore.shieldPresentation

        guard !presentation.snoozeQuotaReached else {
            SharedStore.log(.shieldClosedApp, "Hết lượt gia hạn — đóng ứng dụng.")
            completionHandler(.close)
            return
        }

        let pressedPrimary: Bool
        switch action {
        case .primaryButtonPressed:
            pressedPrimary = true
        case .secondaryButtonPressed:
            pressedPrimary = false
        @unknown default:
            completionHandler(.close)
            return
        }

        switch presentation.mode {
        case .gate:
            if pressedPrimary {
                SharedStore.log(.shieldClosedApp, "Bạn đã chọn đóng ứng dụng. Tuyệt vời!")
                completionHandler(.close)
            } else {
                unlock(settings: settings, completionHandler: completionHandler)
            }

        case .challenge:
            guard let challenge = presentation.challenge else {
                unlock(settings: settings, completionHandler: completionHandler)
                return
            }
            if pressedPrimary == challenge.correctIsPrimary {
                unlock(settings: settings, completionHandler: completionHandler)
            } else {
                failChallenge(settings: settings, completionHandler: completionHandler)
            }
        }
    }

    // MARK: - Outcomes

    /// Waits out the friction delay, then removes the shield.
    private func unlock(
        settings: InterventionSettings,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let delay = TimeInterval(max(0, settings.continueDelaySeconds))

        let finish = {
            let granted = ShieldController.grantSnooze(settings: settings)
            self.refreshLiveActivity()

            guard granted else {
                completionHandler(.close)
                return
            }
            switch settings.unlockBehavior {
            case .closeAndReopen:
                completionHandler(.close)
            case .dismissShield:
                completionHandler(.none)
            }
        }

        if delay > 0 {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay, execute: finish)
        } else {
            finish()
        }
    }

    /// Wrong answer: close the app and stage a fresh question, so the next
    /// attempt cannot be brute-forced by tapping the same button twice.
    private func failChallenge(
        settings: InterventionSettings,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let state = SharedStore.dayState
        SharedStore.shieldPresentation = ShieldPresentation.make(
            minutesUsed: state.reachedMinutes,
            settings: settings,
            snoozeCount: state.snoozeCount
        )
        SharedStore.log(.challengeFailed, "Trả lời sai — ứng dụng được đóng lại.")
        completionHandler(.close)
    }

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
