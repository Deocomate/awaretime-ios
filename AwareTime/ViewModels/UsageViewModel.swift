import Combine
import DeviceActivity
import FamilyControls
import Foundation
import UserNotifications

/// The single app-side view model (MVVM, spec §3.1).
///
/// Owns permissions, the watched selection, the thresholds and the derived
/// dashboard state. Everything it writes goes through the App Group so the
/// extensions see the same truth.
@MainActor
final class UsageViewModel: ObservableObject {

    struct Banner: Identifiable, Equatable {
        enum Kind { case info, success, error }
        let id = UUID()
        let kind: Kind
        let message: String
    }

    // MARK: - Published state

    @Published private(set) var selection: FamilyActivitySelection
    @Published private(set) var settings: InterventionSettings
    @Published private(set) var monitoringEnabled: Bool
    @Published private(set) var dayState: DayState
    @Published private(set) var events: [InterventionEvent] = []
    @Published private(set) var screenTimeStatus: AuthorizationStatus
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isScheduleInstalled = false
    @Published private(set) var liveActivityRunning = false
    @Published private(set) var isWorking = false
    @Published var banner: Banner?
    @Published var onboardingCompleted: Bool

    let demo = DemoModeController()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        selection = SelectionStore.load()
        settings = SharedStore.settings.normalized()
        monitoringEnabled = SharedStore.monitoringEnabled
        dayState = SharedStore.dayState
        screenTimeStatus = AuthorizationService.screenTimeStatus
        onboardingCompleted = SharedStore.onboardingCompleted

        // The demo controller is a nested ObservableObject; forward its
        // changes so the dashboard redraws on every simulated minute.
        demo.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        refresh()
    }

    // MARK: - Derived values

    var appGroupConfigured: Bool { AppGroup.isConfigured }

    var isScreenTimeApproved: Bool { screenTimeStatus.isApproved }

    var isReadyToMonitor: Bool {
        isScreenTimeApproved && !selection.isEmpty
    }

    var ladder: [LadderStep] {
        MonitoringPlan.ladderDescription(settings: settings)
    }

    var progressTowardsShield: Double {
        guard settings.shieldThresholdMinutes > 0 else { return 0 }
        return min(1, Double(dayState.reachedMinutes) / Double(settings.shieldThresholdMinutes))
    }

    var todayEvents: [InterventionEvent] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return events.filter { $0.date >= startOfDay }
    }

    // MARK: - Refresh

    func refresh() {
        settings = SharedStore.settings.normalized()
        monitoringEnabled = SharedStore.monitoringEnabled
        dayState = SharedStore.dayState
        events = Array(SharedStore.eventLog.reversed())
        screenTimeStatus = AuthorizationService.screenTimeStatus
        isScheduleInstalled = MonitoringCoordinator.isMonitoring
        onboardingCompleted = SharedStore.onboardingCompleted

        if #available(iOS 16.1, *) {
            liveActivityRunning = LiveActivityController.isRunning
        }

        Task { [weak self] in
            let status = await AuthorizationService.notificationStatus()
            self?.notificationStatus = status
        }
    }

    /// Called when the app returns to the foreground: puts the shield back if
    /// a snooze quietly expired while we were away, then refreshes the UI.
    func reconcileOnForeground() {
        if ShieldController.reapplyIfSnoozeExpired(settings: SharedStore.settings) {
            SharedStore.log(.shieldReapplied, "Hết gia hạn — bật lại màn chắn.")
        }
        syncLiveActivity()
        refresh()
    }

    // MARK: - Permissions

    func requestScreenTimeAccess() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await AuthorizationService.requestScreenTime()
            screenTimeStatus = AuthorizationService.screenTimeStatus
            banner = Banner(kind: .success, message: "Đã cấp quyền Screen Time.")
        } catch {
            screenTimeStatus = AuthorizationService.screenTimeStatus
            banner = Banner(kind: .error, message: AuthorizationService.describe(error))
        }
    }

    func requestNotificationAccess() async {
        let granted = await AuthorizationService.requestNotifications()
        notificationStatus = await AuthorizationService.notificationStatus()
        banner = granted
            ? Banner(kind: .success, message: "Đã bật thông báo.")
            : Banner(kind: .error, message: "Thông báo đang bị tắt. Bật lại trong Cài đặt → AwareTime → Thông báo.")
    }

    func sendTestNotification() {
        NotificationScheduler.postTest()
        banner = Banner(kind: .info, message: "Đã gửi thông báo thử.")
    }

    // MARK: - Selection

    /// Called once the picker sheet is dismissed, so a half-finished
    /// selection never reinstalls the DeviceActivity schedule.
    func updateSelection(_ newValue: FamilyActivitySelection) {
        selection = newValue
        SelectionStore.save(newValue)
        do {
            try MonitoringCoordinator.restartIfRunning(selection: newValue, settings: settings)
        } catch {
            banner = Banner(kind: .error, message: error.localizedDescription)
        }
        isScheduleInstalled = MonitoringCoordinator.isMonitoring
        monitoringEnabled = SharedStore.monitoringEnabled
        syncLiveActivity()
    }

    func clearSelection() {
        updateSelection(FamilyActivitySelection())
    }

    // MARK: - Settings

    func apply(settings newValue: InterventionSettings) {
        let normalized = newValue.normalized()
        guard normalized != settings else { return }

        let needsReschedule = normalized.notificationThresholdMinutes != settings.notificationThresholdMinutes
            || normalized.warningThresholdMinutes != settings.warningThresholdMinutes
            || normalized.shieldThresholdMinutes != settings.shieldThresholdMinutes
            || normalized.snoozeMinutes != settings.snoozeMinutes
            || normalized.shieldEnabled != settings.shieldEnabled
            || normalized.notificationsEnabled != settings.notificationsEnabled

        settings = normalized
        SharedStore.settings = normalized

        if needsReschedule {
            do {
                try MonitoringCoordinator.restartIfRunning(selection: selection, settings: normalized)
            } catch {
                banner = Banner(kind: .error, message: error.localizedDescription)
            }
            isScheduleInstalled = MonitoringCoordinator.isMonitoring
        }

        if !normalized.liveActivityEnabled {
            endLiveActivity()
        } else {
            syncLiveActivity()
        }
    }

    func resetSettings() {
        apply(settings: .default)
        banner = Banner(kind: .info, message: "Đã đưa các mốc về mặc định.")
    }

    // MARK: - Monitoring

    func setMonitoring(_ enabled: Bool) {
        if enabled {
            startMonitoring()
        } else {
            MonitoringCoordinator.disable()
            endLiveActivity()
            monitoringEnabled = false
            isScheduleInstalled = false
            refresh()
        }
    }

    func startMonitoring() {
        do {
            try MonitoringCoordinator.start(selection: selection, settings: settings)
            monitoringEnabled = true
            isScheduleInstalled = MonitoringCoordinator.isMonitoring
            startLiveActivity()
            banner = Banner(kind: .success, message: "Đang giám sát \(selection.watchedCount) mục.")
        } catch {
            monitoringEnabled = false
            banner = Banner(kind: .error, message: error.localizedDescription)
        }
        refresh()
    }

    // MARK: - Manual shield control

    func liftShieldNow() {
        ShieldController.removeShield()
        SharedStore.mutateDayState { state in
            state.shieldActive = false
            state.snoozeUntil = nil
        }
        SharedStore.log(.shieldLifted, "Gỡ màn chắn thủ công từ ứng dụng.")
        syncLiveActivity()
        refresh()
        banner = Banner(kind: .info, message: "Đã gỡ màn chắn.")
    }

    func applyShieldNow() {
        guard !selection.isEmpty else {
            banner = Banner(kind: .error, message: "Hãy chọn ứng dụng cần theo dõi trước.")
            return
        }
        ShieldController.escalateToShield(
            minutesUsed: max(dayState.reachedMinutes, settings.shieldThresholdMinutes),
            settings: settings
        )
        SharedStore.log(.shieldApplied, "Bật màn chắn thủ công để kiểm tra.")
        syncLiveActivity()
        refresh()
        banner = Banner(kind: .info, message: "Đã bật màn chắn. Mở một ứng dụng được theo dõi để xem.")
    }

    func resetToday() {
        ShieldController.removeShield()
        SharedStore.resetDayState()
        SharedStore.shieldPresentation = .placeholder
        SharedStore.log(.monitoringStarted, "Đặt lại bộ đếm của hôm nay.")
        syncLiveActivity()
        refresh()
    }

    func clearHistory() {
        SharedStore.clearEventLog()
        events = []
    }

    // MARK: - Live Activity

    func startLiveActivity() {
        guard settings.liveActivityEnabled else { return }
        if #available(iOS 16.1, *) {
            let state = AwareTimeActivityAttributes.ContentState.snapshot(
                dayState: SharedStore.dayState,
                settings: settings
            )
            let started = LiveActivityController.start(
                watchedCount: max(1, selection.watchedCount),
                state: state
            )
            liveActivityRunning = LiveActivityController.isRunning
            if !started, !liveActivityRunning {
                banner = Banner(
                    kind: .info,
                    message: "Live Activity đang bị tắt. Bật trong Cài đặt → AwareTime → Hoạt động trực tiếp."
                )
            }
        }
    }

    func syncLiveActivity() {
        guard settings.liveActivityEnabled else { return }
        if #available(iOS 16.1, *) {
            guard LiveActivityController.isRunning else { return }
            let state = AwareTimeActivityAttributes.ContentState.snapshot(
                dayState: SharedStore.dayState,
                settings: settings
            )
            Task { await LiveActivityController.update(state: state) }
        }
    }

    func endLiveActivity() {
        if #available(iOS 16.1, *) {
            Task { [weak self] in
                await LiveActivityController.end()
                self?.liveActivityRunning = false
            }
        }
    }

    // MARK: - Demo mode

    func startDemo() {
        demo.start(settings: settings, watchedCount: selection.watchedCount)
        banner = Banner(
            kind: .info,
            message: "Đang mô phỏng: 1 phút sử dụng ≈ \(String(format: "%.1f", demo.secondsPerSimulatedMinute)) giây thật."
        )
    }

    func stopDemo() {
        demo.reset()
        refresh()
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        SharedStore.onboardingCompleted = true
        onboardingCompleted = true
    }

    func resetEverything() {
        MonitoringCoordinator.disable()
        endLiveActivity()
        ShieldController.clearAll()
        SharedStore.resetEverything()
        SelectionStore.clear()
        selection = FamilyActivitySelection()
        settings = .default
        onboardingCompleted = false
        refresh()
        banner = Banner(kind: .info, message: "Đã xoá toàn bộ dữ liệu AwareTime.")
    }
}
