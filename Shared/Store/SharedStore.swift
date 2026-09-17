import Foundation

/// Typed access to the App Group `UserDefaults` suite.
///
/// Every property is safe to touch from the main app, the DeviceActivity
/// monitor extension and both shield extensions.
enum SharedStore {

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static var defaults: UserDefaults { AppGroup.defaults }

    // MARK: - Generic helpers

    static func value<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    static func set<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    static func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
    }

    // MARK: - Settings

    static var settings: InterventionSettings {
        get { SharedStore.value(InterventionSettings.self, forKey: SharedKey.settings) ?? .default }
        set { SharedStore.set(newValue.normalized(), forKey: SharedKey.settings) }
    }

    // MARK: - Monitoring flag

    static var monitoringEnabled: Bool {
        get { defaults.bool(forKey: SharedKey.monitoringEnabled) }
        set { defaults.set(newValue, forKey: SharedKey.monitoringEnabled) }
    }

    static var onboardingCompleted: Bool {
        get { defaults.bool(forKey: SharedKey.onboardingCompleted) }
        set { defaults.set(newValue, forKey: SharedKey.onboardingCompleted) }
    }

    /// How many apps / categories / sites are watched. Cached as a plain Int
    /// so the widget does not need the Family Controls entitlement just to
    /// count tokens.
    static var watchedCount: Int {
        get { defaults.integer(forKey: SharedKey.watchedCount) }
        set { defaults.set(newValue, forKey: SharedKey.watchedCount) }
    }

    // MARK: - Day state

    static var dayState: DayState {
        get {
            let stored = SharedStore.value(DayState.self, forKey: SharedKey.dayState) ?? DayState.empty()
            return stored.rolledOverIfNeeded()
        }
        set { SharedStore.set(newValue, forKey: SharedKey.dayState) }
    }

    /// Read–modify–write helper so callers cannot forget the day rollover.
    @discardableResult
    static func mutateDayState(_ body: (inout DayState) -> Void) -> DayState {
        var state = dayState
        body(&state)
        dayState = state
        return state
    }

    static func resetDayState() {
        dayState = DayState.empty()
    }

    // MARK: - Shield presentation

    static var shieldPresentation: ShieldPresentation {
        get { SharedStore.value(ShieldPresentation.self, forKey: SharedKey.shieldPresentation) ?? .placeholder }
        set { SharedStore.set(newValue, forKey: SharedKey.shieldPresentation) }
    }

    // MARK: - Event log

    static let eventLogLimit = 120

    static var eventLog: [InterventionEvent] {
        get { SharedStore.value([InterventionEvent].self, forKey: SharedKey.eventLog) ?? [] }
        set {
            let trimmed = Array(newValue.suffix(SharedStore.eventLogLimit))
            SharedStore.set(trimmed, forKey: SharedKey.eventLog)
        }
    }

    static func log(_ kind: InterventionEvent.Kind, _ message: String, minutes: Int? = nil) {
        var events = eventLog
        events.append(InterventionEvent(kind: kind, message: message, minutes: minutes))
        eventLog = events
    }

    static func clearEventLog() {
        remove(forKey: SharedKey.eventLog)
    }

    // MARK: - Full reset

    static func resetEverything() {
        [
            SharedKey.settings,
            SharedKey.selection,
            SharedKey.monitoringEnabled,
            SharedKey.dayState,
            SharedKey.eventLog,
            SharedKey.shieldPresentation,
            SharedKey.onboardingCompleted,
            SharedKey.lastKnownAuthorization,
            SharedKey.watchedCount
        ].forEach { defaults.removeObject(forKey: $0) }
    }
}
