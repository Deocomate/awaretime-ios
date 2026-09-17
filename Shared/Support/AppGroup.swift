import Foundation

/// Identifiers shared between the main app and every extension.
///
/// The App Group id is injected into each target's `Info.plist` as
/// `AwareTimeAppGroupIdentifier` (value `$(APP_GROUP_ID)`), so changing the
/// bundle id prefix in the Xcode project is enough — no code edits required.
enum AppGroup {

    /// Used when the Info.plist key is missing (should not happen in a
    /// correctly configured build, but keeps the app usable instead of
    /// crashing).
    static let fallbackIdentifier = "group.com.deocomate.awaretime"

    static let identifier: String = {
        let value = Bundle.main.object(forInfoDictionaryKey: "AwareTimeAppGroupIdentifier") as? String
        if let value, !value.isEmpty, !value.hasPrefix("$(") {
            return value
        }
        return fallbackIdentifier
    }()

    /// Shared `UserDefaults` suite. Falls back to `.standard` so that a
    /// misconfigured App Group degrades instead of trapping.
    static let defaults: UserDefaults = {
        UserDefaults(suiteName: identifier) ?? .standard
    }()

    static var isConfigured: Bool {
        UserDefaults(suiteName: identifier) != nil
    }
}

/// Keys used inside the shared `UserDefaults` suite.
enum SharedKey {
    static let settings = "awaretime.settings"
    static let selection = "awaretime.selection"
    static let monitoringEnabled = "awaretime.monitoringEnabled"
    static let dayState = "awaretime.dayState"
    static let eventLog = "awaretime.eventLog"
    static let shieldPresentation = "awaretime.shieldPresentation"
    static let onboardingCompleted = "awaretime.onboardingCompleted"
    static let watchedCount = "awaretime.watchedCount"
    static let lastKnownAuthorization = "awaretime.lastKnownAuthorization"
}
