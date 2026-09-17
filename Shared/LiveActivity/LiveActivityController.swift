import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Starts / updates / ends the AwareTime Live Activity.
///
/// `Activity.request` may only be called while the app is in the foreground,
/// so the activity is started by the app when monitoring is switched on and
/// merely *updated* from the DeviceActivity monitor extension.
@available(iOS 16.1, *)
enum LiveActivityController {

    static var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private static var running: [Activity<AwareTimeActivityAttributes>] {
        Activity<AwareTimeActivityAttributes>.activities
    }

    static var isRunning: Bool { !running.isEmpty }

    // MARK: - Start (app only)

    @discardableResult
    static func start(
        watchedCount: Int,
        state: AwareTimeActivityAttributes.ContentState
    ) -> Bool {
        guard areActivitiesEnabled else { return false }
        if isRunning {
            Task { await update(state: state) }
            return true
        }

        let attributes = AwareTimeActivityAttributes(
            watchedCount: watchedCount,
            startedAt: Date()
        )

        do {
            if #available(iOS 16.2, *) {
                _ = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: staleDate(from: state)),
                    pushType: nil
                )
            } else {
                _ = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Update (app + monitor extension)

    static func update(state: AwareTimeActivityAttributes.ContentState) async {
        for activity in running {
            if #available(iOS 16.2, *) {
                await activity.update(
                    ActivityContent(state: state, staleDate: staleDate(from: state))
                )
            } else {
                await activity.update(using: state)
            }
        }
    }

    /// Synchronous wrapper for use inside app extensions, which may be torn
    /// down as soon as the delegate callback returns.
    static func updateBlocking(
        state: AwareTimeActivityAttributes.ContentState,
        timeout: TimeInterval = 2
    ) {
        guard !running.isEmpty else { return }
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) {
            await update(state: state)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + timeout)
    }

    // MARK: - End

    static func end() async {
        for activity in running {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(using: nil, dismissalPolicy: .immediate)
            }
        }
    }

    static func endBlocking(timeout: TimeInterval = 2) {
        guard !running.isEmpty else { return }
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) {
            await end()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + timeout)
    }

    // MARK: - Helpers

    /// Keeps the Lock Screen card from showing obviously stale numbers.
    private static func staleDate(
        from state: AwareTimeActivityAttributes.ContentState
    ) -> Date? {
        if let snoozeUntil = state.snoozeUntil, snoozeUntil > state.updatedAt {
            return snoozeUntil
        }
        return state.updatedAt.addingTimeInterval(60 * 60)
    }
}
#endif
