import SwiftUI
import WidgetKit

/// A small Home Screen / Lock Screen widget mirroring today's state.
struct AwareTimeStatusWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AwareTimeStatusWidget", provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .awareWidgetBackground(Color.awareInk.gradient)
        }
        .configurationDisplayName("Trạng thái AwareTime")
        .description("Mức cảnh báo và số phút đã dùng hôm nay.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct StatusEntry: TimelineEntry {
    let date: Date
    let level: InterventionLevel
    let minutesUsed: Int
    let shieldAtMinutes: Int
    let monitoring: Bool
    let watchedCount: Int
    let snoozeUntil: Date?
}

struct StatusProvider: TimelineProvider {

    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(
            date: Date(),
            level: .none,
            minutesUsed: 0,
            shieldAtMinutes: 45,
            monitoring: true,
            watchedCount: 3,
            snoozeUntil: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let entry = currentEntry()
        let refresh = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func currentEntry() -> StatusEntry {
        let state = SharedStore.dayState
        let settings = SharedStore.settings.normalized()
        return StatusEntry(
            date: Date(),
            level: state.level,
            minutesUsed: state.reachedMinutes,
            shieldAtMinutes: settings.shieldThresholdMinutes,
            monitoring: SharedStore.monitoringEnabled,
            watchedCount: SharedStore.watchedCount,
            snoozeUntil: state.snoozeUntil
        )
    }
}

struct StatusWidgetView: View {

    @Environment(\.widgetFamily) private var family
    let entry: StatusEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessory
        default:
            standard
        }
    }

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("AwareTime · \(entry.level.shortTitle)")
                .font(.caption2.weight(.semibold))
            Text("\(entry.minutesUsed)/\(entry.shieldAtMinutes) phút")
                .font(.headline)
                .monospacedDigit()
            ProgressView(value: progress)
        }
    }

    private var standard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: entry.monitoring ? entry.level.symbolName : "pause.circle.fill")
                    .foregroundStyle(entry.monitoring ? Color.aware(for: entry.level) : .white.opacity(0.6))
                Text(entry.monitoring ? entry.level.title : "Đang tạm dừng")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text("\(entry.minutesUsed)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("phút")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            ProgressView(value: progress)
                .tint(Color.aware(for: entry.level))

            Text(footnote)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)
        }
        .padding(4)
    }

    private var progress: Double {
        guard entry.shieldAtMinutes > 0 else { return 0 }
        return min(1, Double(entry.minutesUsed) / Double(entry.shieldAtMinutes))
    }

    private var footnote: String {
        if let snoozeUntil = entry.snoozeUntil, snoozeUntil > entry.date {
            return "Gia hạn đến \(AwareTimeFormat.clock(snoozeUntil))"
        }
        if !entry.monitoring { return "Bật giám sát trong ứng dụng" }
        if entry.watchedCount == 0 { return "Chưa chọn ứng dụng nào" }
        return "Chặn ở \(entry.shieldAtMinutes) phút · \(entry.watchedCount) mục"
    }
}
