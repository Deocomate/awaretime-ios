import FamilyControls
import Foundation
import ManagedSettings

extension ManagedSettingsStore.Name {
    /// A named store keeps AwareTime's restrictions isolated from anything
    /// else (including Apple's own Screen Time settings).
    static let awareTime = Self("awaretime.shield")
}

/// Applies and removes the `ManagedSettings` shield.
///
/// Shared by the monitor extension (applies at level 3 and re-applies when a
/// snooze expires), the shield action extension (lifts it) and the main app
/// (manual override + reconciliation on launch).
enum ShieldController {

    static let store = ManagedSettingsStore(named: .awareTime)

    /// Puts every watched token behind the shield.
    static func applyShield(for selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens

        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)

        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil
            : selection.webDomainTokens

        store.shield.webDomainCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    /// Removes every restriction this app owns.
    static func removeShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }

    static func clearAll() {
        store.clearAllSettings()
    }

    static var isShieldApplied: Bool {
        if let apps = store.shield.applications, !apps.isEmpty { return true }
        if let domains = store.shield.webDomains, !domains.isEmpty { return true }
        if store.shield.applicationCategories != nil { return true }
        if store.shield.webDomainCategories != nil { return true }
        return false
    }

    // MARK: - High level transitions

    /// Level 3: shield the watched apps and stage the screen the shield
    /// extensions will render.
    static func escalateToShield(minutesUsed: Int, settings: InterventionSettings) {
        let selection = SelectionStore.load()
        guard !selection.isEmpty, settings.shieldEnabled else { return }

        applyShield(for: selection)

        let snoozeCount = SharedStore.dayState.snoozeCount
        SharedStore.shieldPresentation = ShieldPresentation.make(
            minutesUsed: minutesUsed,
            settings: settings,
            snoozeCount: snoozeCount
        )

        SharedStore.mutateDayState { state in
            state.level = max(state.level, .shield)
            state.reachedMinutes = max(state.reachedMinutes, minutesUsed)
            state.shieldActive = true
            state.snoozeUntil = nil
            state.lastEventDate = Date()
        }
    }

    /// Grants a temporary unlock. Returns `false` when the daily quota is
    /// already used up.
    @discardableResult
    static func grantSnooze(settings: InterventionSettings, now: Date = Date()) -> Bool {
        let state = SharedStore.dayState
        if settings.maxSnoozesPerDay > 0, state.snoozeCount >= settings.maxSnoozesPerDay {
            SharedStore.log(
                .snoozeDenied,
                "Đã dùng hết \(settings.maxSnoozesPerDay) lần gia hạn của hôm nay."
            )
            return false
        }

        removeShield()

        SharedStore.mutateDayState { state in
            state.shieldActive = false
            state.snoozeUntil = now.addingTimeInterval(TimeInterval(settings.snoozeMinutes * 60))
            state.snoozeCount += 1
        }

        SharedStore.log(
            .shieldLifted,
            "Gỡ chặn tạm thời \(settings.snoozeMinutes) phút.",
            minutes: settings.snoozeMinutes
        )
        return true
    }

    /// Re-applies the shield when a snooze has run out. Called from the
    /// monitor extension's periodic re-shield events and from the app when it
    /// comes back to the foreground.
    @discardableResult
    static func reapplyIfSnoozeExpired(settings: InterventionSettings, now: Date = Date()) -> Bool {
        let state = SharedStore.dayState
        guard settings.shieldEnabled, state.level >= .shield else { return false }
        if let snoozeUntil = state.snoozeUntil, snoozeUntil > now { return false }
        if state.shieldActive, isShieldApplied { return false }

        let selection = SelectionStore.load()
        guard !selection.isEmpty else { return false }

        applyShield(for: selection)
        SharedStore.shieldPresentation = ShieldPresentation.make(
            minutesUsed: state.reachedMinutes,
            settings: settings,
            snoozeCount: state.snoozeCount
        )
        SharedStore.mutateDayState { state in
            state.shieldActive = true
            state.snoozeUntil = nil
        }
        return true
    }
}
