import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI

/// One row of the usage breakdown.
struct AppUsageRow: Identifiable {
    var id: String
    var name: String
    var duration: TimeInterval
    var token: ApplicationToken?
}

/// Aggregated payload handed to `TotalActivityView`.
struct ActivityReport {
    var totalDuration: TimeInterval = 0
    var watchedDuration: TimeInterval = 0
    var rows: [AppUsageRow] = []
    var isFilteredToSelection: Bool = false
}

struct TotalActivityReport: DeviceActivityReportScene {

    let context: DeviceActivityReport.Context = .awareTimeTotal
    let content: (ActivityReport) -> TotalActivityView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ActivityReport {
        // Reading the shared selection lets the report highlight exactly the
        // apps the user asked AwareTime to watch. If it is unavailable we fall
        // back to showing everything the filter returned.
        let selection = SelectionStore.load()
        let watchedTokens = selection.applicationTokens
        let isFiltered = !watchedTokens.isEmpty

        var totalDuration: TimeInterval = 0
        var watchedDuration: TimeInterval = 0
        var durations: [String: TimeInterval] = [:]
        var names: [String: String] = [:]
        var tokens: [String: ApplicationToken] = [:]

        for await result in data {
            for await segment in result.activitySegments {
                totalDuration += segment.totalActivityDuration

                for await category in segment.categories {
                    for await app in category.applications {
                        let duration = app.totalActivityDuration
                        guard duration > 0 else { continue }

                        let token = app.application.token
                        if let token, watchedTokens.contains(token) {
                            watchedDuration += duration
                        } else if isFiltered {
                            continue
                        }

                        let key = app.application.bundleIdentifier
                            ?? app.application.localizedDisplayName
                            ?? UUID().uuidString
                        durations[key, default: 0] += duration
                        names[key] = app.application.localizedDisplayName ?? "Ứng dụng khác"
                        if let token { tokens[key] = token }
                    }
                }
            }
        }

        let rows = durations
            .map { key, duration in
                AppUsageRow(
                    id: key,
                    name: names[key] ?? "Ứng dụng khác",
                    duration: duration,
                    token: tokens[key]
                )
            }
            .sorted { $0.duration > $1.duration }

        return ActivityReport(
            totalDuration: totalDuration,
            watchedDuration: isFiltered ? watchedDuration : totalDuration,
            rows: Array(rows.prefix(12)),
            isFilteredToSelection: isFiltered
        )
    }
}
