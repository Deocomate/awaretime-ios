import FamilyControls
import Foundation
import ManagedSettings

/// Persists the `FamilyActivitySelection` chosen with `FamilyActivityPicker`.
///
/// `FamilyActivitySelection` is `Codable`, but its tokens are opaque and only
/// meaningful to targets that share the same App Group + Family Controls
/// entitlement — which is exactly why it lives in the shared suite.
enum SelectionStore {

    static func load() -> FamilyActivitySelection {
        guard let data = AppGroup.defaults.data(forKey: SharedKey.selection) else {
            return FamilyActivitySelection()
        }
        return (try? JSONDecoder().decode(FamilyActivitySelection.self, from: data))
            ?? FamilyActivitySelection()
    }

    static func save(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        AppGroup.defaults.set(data, forKey: SharedKey.selection)
        SharedStore.watchedCount = selection.watchedCount
    }

    static func clear() {
        AppGroup.defaults.removeObject(forKey: SharedKey.selection)
        SharedStore.watchedCount = 0
    }
}

extension FamilyActivitySelection {

    var isEmpty: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }

    /// Number of distinct things the user asked us to watch.
    var watchedCount: Int {
        applicationTokens.count + categoryTokens.count + webDomainTokens.count
    }

    var summary: String {
        var parts: [String] = []
        if !applicationTokens.isEmpty { parts.append("\(applicationTokens.count) ứng dụng") }
        if !categoryTokens.isEmpty { parts.append("\(categoryTokens.count) danh mục") }
        if !webDomainTokens.isEmpty { parts.append("\(webDomainTokens.count) website") }
        return parts.isEmpty ? "Chưa chọn gì" : parts.joined(separator: " · ")
    }
}
