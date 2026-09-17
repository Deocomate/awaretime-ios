import Foundation

/// Reads the entitlements that were actually baked into *this* build.
///
/// The Screen Time API fails with a bare "Couldn't communicate with a helper
/// application" when the binary is not entitled to talk to the Screen Time
/// daemon. That message says nothing about the cause, so AwareTime inspects
/// its own `embedded.mobileprovision` and reports the real reason.
///
/// Uses no private API: the profile is a CMS blob with an XML plist inside,
/// and the plist is extracted by locating its start and end markers.
enum ProvisioningProfileInspector {

    // MARK: - Environment

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Profile contents

    struct Profile {
        var name: String?
        var teamIdentifier: String?
        var expirationDate: Date?
        var entitlements: [String: Any]

        /// True for a development profile (`get-task-allow`).
        var isDevelopment: Bool {
            entitlements["get-task-allow"] as? Bool == true
        }

        var hasFamilyControls: Bool {
            entitlements[EntitlementKey.familyControls] as? Bool == true
        }

        var hasTimeSensitiveNotifications: Bool {
            entitlements[EntitlementKey.timeSensitive] as? Bool == true
        }

        var appGroups: [String] {
            entitlements[EntitlementKey.appGroups] as? [String] ?? []
        }

        var isExpired: Bool {
            guard let expirationDate else { return false }
            return expirationDate < Date()
        }
    }

    enum EntitlementKey {
        static let familyControls = "com.apple.developer.family-controls"
        static let timeSensitive = "com.apple.developer.usernotifications.time-sensitive"
        static let appGroups = "com.apple.security.application-groups"
    }

    /// Whether this build carries the Family Controls entitlement.
    enum FamilyControlsState {
        /// The profile is present and grants the entitlement.
        case granted
        /// The profile is present but does not list the entitlement.
        case missing
        /// No embedded profile — an App Store build, or a Simulator build.
        case indeterminate
    }

    static let profile: Profile? = loadProfile()

    static var familyControlsState: FamilyControlsState {
        guard let profile else { return .indeterminate }
        return profile.hasFamilyControls ? .granted : .missing
    }

    // MARK: - Parsing

    private static func loadProfile() -> Profile? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let plistData = extractPropertyList(from: data),
              let plist = try? PropertyListSerialization.propertyList(
                  from: plistData,
                  options: [],
                  format: nil
              ) as? [String: Any]
        else { return nil }

        return Profile(
            name: plist["Name"] as? String,
            teamIdentifier: (plist["TeamIdentifier"] as? [String])?.first,
            expirationDate: plist["ExpirationDate"] as? Date,
            entitlements: plist["Entitlements"] as? [String: Any] ?? [:]
        )
    }

    /// Carves the XML plist out of the signed CMS container.
    private static func extractPropertyList(from data: Data) -> Data? {
        let opening = Data("<?xml".utf8)
        let closing = Data("</plist>".utf8)

        guard let start = data.range(of: opening) else { return nil }
        guard let end = data.range(
            of: closing,
            options: [],
            in: start.lowerBound..<data.endIndex
        ) else { return nil }

        return data[start.lowerBound..<end.upperBound]
    }
}
