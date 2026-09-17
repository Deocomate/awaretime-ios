import FamilyControls
import ManagedSettings
import SwiftUI

/// The SwiftUI body that the system renders inside the host app's
/// `DeviceActivityReport` view.
struct TotalActivityView: View {

    let report: ActivityReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if report.rows.isEmpty {
                Text("Chưa có dữ liệu sử dụng cho hôm nay.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(report.rows) { row in
                        AppUsageRowView(row: row, total: maxDuration)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(report.isFilteredToSelection ? "Ứng dụng đang theo dõi" : "Tổng thời gian dùng")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(AwareTimeFormat.duration(report.watchedDuration))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
            if report.isFilteredToSelection, report.totalDuration > report.watchedDuration {
                Text("Toàn thiết bị: \(AwareTimeFormat.duration(report.totalDuration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var maxDuration: TimeInterval {
        max(1, report.rows.map(\.duration).max() ?? 1)
    }
}

private struct AppUsageRowView: View {

    let row: AppUsageRow
    let total: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let token = row.token {
                    Label(token)
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                        .lineLimit(1)
                } else {
                    Text(row.name)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(AwareTimeFormat.duration(row.duration))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.awareCalm)
                        .frame(width: max(4, proxy.size.width * (row.duration / total)))
                }
            }
            .frame(height: 6)
        }
    }
}
