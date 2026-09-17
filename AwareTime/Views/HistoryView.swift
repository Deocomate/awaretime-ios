import SwiftUI

/// Event log written by the app and both extensions.
struct HistoryView: View {

    @EnvironmentObject private var viewModel: UsageViewModel
    @State private var showTodayOnly = false

    private var events: [InterventionEvent] {
        showTodayOnly ? viewModel.todayEvents : viewModel.events
    }

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(events) { event in
                                EventRow(event: event)
                            }
                        } header: {
                            Text(showTodayOnly ? "Hôm nay" : "Gần đây")
                        } footer: {
                            Text("Ghi nhận bởi ứng dụng và các extension. Giữ lại \(SharedStore.eventLogLimit) sự kiện gần nhất.")
                        }
                    }
                }
            }
            .navigationTitle("Lịch sử")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(showTodayOnly ? "Tất cả" : "Hôm nay") {
                        showTodayOnly.toggle()
                    }
                    .font(.footnote)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            viewModel.refresh()
                        } label: {
                            Label("Làm mới", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive) {
                            viewModel.clearHistory()
                        } label: {
                            Label("Xoá lịch sử", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear { viewModel.refresh() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.secondary)
            Text("Chưa có sự kiện nào")
                .font(.headline)
            Text("Bật giám sát rồi dùng thử một ứng dụng được theo dõi, hoặc chạy “Chạy thử nhanh” ở tab Hôm nay.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private struct EventRow: View {

    let event: InterventionEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind.symbolName)
                .font(.subheadline)
                .foregroundStyle(event.kind.isAlert ? Color.awareAmber : Color.awareCalm)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(AwareTimeFormat.dayAndClock(event.date))
                    if let minutes = event.minutes {
                        Text("· \(AwareTimeFormat.minutes(minutes))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
