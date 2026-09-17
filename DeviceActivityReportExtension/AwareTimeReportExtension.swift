import DeviceActivity
import SwiftUI

/// Renders real Screen Time numbers inside AwareTime's dashboard.
///
/// A report extension is sandboxed: it can read activity data and draw it, but
/// it cannot send anything back to the app. That is why the dashboard embeds
/// this view instead of asking for a number.
@main
struct AwareTimeReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { report in
            TotalActivityView(report: report)
        }
    }
}
