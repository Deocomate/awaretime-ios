import DeviceActivity
import FamilyControls
import Foundation

/// Installs and removes the DeviceActivity schedule (spec §2.2).
enum MonitoringCoordinator {

    private static let center = DeviceActivityCenter()

    static var isMonitoring: Bool {
        center.activities.contains(MonitoringPlan.activityName)
    }

    enum StartError: LocalizedError {
        case emptySelection
        case notAuthorized
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .emptySelection:
                return "Hãy chọn ít nhất một ứng dụng để theo dõi."
            case .notAuthorized:
                return "Cần cấp quyền Screen Time trước khi bật giám sát."
            case .underlying(let error):
                return "Không bật được giám sát: \(error.localizedDescription)"
            }
        }
    }

    static func start(
        selection: FamilyActivitySelection,
        settings: InterventionSettings
    ) throws {
        guard !selection.isEmpty else { throw StartError.emptySelection }
        guard AuthorizationService.screenTimeStatus.isApproved else { throw StartError.notAuthorized }

        stop()

        let settings = settings.normalized()
        let events = MonitoringPlan.events(selection: selection, settings: settings)

        do {
            try center.startMonitoring(
                MonitoringPlan.activityName,
                during: MonitoringPlan.schedule(),
                events: events
            )
        } catch {
            throw StartError.underlying(error)
        }

        SharedStore.monitoringEnabled = true
        SharedStore.log(
            .monitoringStarted,
            "Bắt đầu giám sát \(selection.watchedCount) mục · mốc \(settings.notificationThresholdMinutes)/\(settings.warningThresholdMinutes)/\(settings.shieldThresholdMinutes) phút."
        )
    }

    static func stop() {
        center.stopMonitoring([MonitoringPlan.activityName])
    }

    /// Full teardown: stop the schedule, drop the shield and clear the state.
    static func disable() {
        stop()
        ShieldController.removeShield()
        SharedStore.monitoringEnabled = false
        SharedStore.mutateDayState { state in
            state.shieldActive = false
            state.snoozeUntil = nil
        }
        SharedStore.log(.monitoringStopped, "Đã tắt giám sát và gỡ màn chắn.")
    }

    /// Re-installs the schedule after the selection or thresholds changed.
    static func restartIfRunning(
        selection: FamilyActivitySelection,
        settings: InterventionSettings
    ) throws {
        guard SharedStore.monitoringEnabled else { return }
        guard !selection.isEmpty else {
            disable()
            return
        }
        try start(selection: selection, settings: settings)
    }
}
