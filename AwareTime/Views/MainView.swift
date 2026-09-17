import DeviceActivity
import FamilyControls
import SwiftUI

/// Dashboard (spec §3.1): today's state, the ladder, real Screen Time numbers
/// and the controls.
struct MainView: View {

    @EnvironmentObject private var viewModel: UsageViewModel
    @State private var showPicker = false
    @State private var showShieldPreview = false
    @State private var reportFilter = MainView.todayFilter()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let banner = viewModel.banner {
                        BannerView(banner: banner) { viewModel.banner = nil }
                    }

                    if !viewModel.isScreenTimeApproved {
                        permissionCard
                    }

                    statusCard
                    usageCard
                    ladderCard
                    watchedCard
                    controlsCard
                    demoCard
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AwareTime")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.refresh()
                        reportFilter = MainView.todayFilter()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Làm mới")
                }
            }
            .sheet(isPresented: $showPicker) {
                AppPickerView(initialSelection: viewModel.selection) { selection in
                    viewModel.updateSelection(selection)
                    reportFilter = MainView.todayFilter()
                }
            }
            .sheet(isPresented: $showShieldPreview) {
                shieldPreviewSheet
            }
            .refreshable { viewModel.refresh() }
        }
    }

    // MARK: - Cards

    private var permissionCard: some View {
        CardView(
            title: "Chưa kết nối Screen Time",
            systemImage: "exclamationmark.triangle.fill",
            footnote: "Không có quyền này, AwareTime không đo được thời gian dùng ứng dụng. Chế độ mô phỏng bên dưới vẫn hoạt động để bạn thử giao diện."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.screenTimeStatus.vietnameseTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await viewModel.requestScreenTimeAccess() }
                } label: {
                    Label("Cấp quyền Screen Time", systemImage: "hourglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.awareCalm)
                .disabled(viewModel.isWorking)
            }
        }
    }

    private var statusCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.monitoringEnabled ? "Đang giám sát" : "Đang tạm dừng")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(viewModel.dayState.reachedMinutes)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("/ \(viewModel.settings.shieldThresholdMinutes) phút")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    StatusPill(
                        text: viewModel.dayState.level.title,
                        systemImage: viewModel.dayState.level.symbolName,
                        tone: tone(for: viewModel.dayState.level)
                    )
                }

                ProgressView(value: viewModel.progressTowardsShield)
                    .tint(Color.aware(for: viewModel.dayState.level))

                HStack(spacing: 8) {
                    StatusPill(
                        text: viewModel.isScheduleInstalled ? "Lịch đã cài" : "Chưa cài lịch",
                        systemImage: viewModel.isScheduleInstalled ? "calendar.badge.checkmark" : "calendar.badge.exclamationmark",
                        tone: viewModel.isScheduleInstalled ? .good : .neutral
                    )
                    if viewModel.liveActivityRunning {
                        StatusPill(text: "Live Activity", systemImage: "bolt.fill", tone: .good)
                    }
                    if viewModel.dayState.shieldActive {
                        StatusPill(text: "Đang chặn", systemImage: "hand.raised.fill", tone: .bad)
                    }
                    if viewModel.dayState.isSnoozing {
                        StatusPill(
                            text: "Gia hạn đến \(AwareTimeFormat.clock(viewModel.dayState.snoozeUntil ?? Date()))",
                            systemImage: "clock.arrow.circlepath",
                            tone: .warn
                        )
                    }
                }

                if viewModel.dayState.snoozeCount > 0 {
                    Text("Đã gia hạn \(viewModel.dayState.snoozeCount) lần hôm nay.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Real Screen Time data, rendered by the report extension.
    private var usageCard: some View {
        CardView(
            title: "Thời gian sử dụng hôm nay",
            systemImage: "chart.bar.fill",
            footnote: "Số liệu do iOS cung cấp qua DeviceActivityReport. Có thể trễ vài phút so với thực tế."
        ) {
            if viewModel.isScreenTimeApproved {
                DeviceActivityReport(.awareTimeTotal, filter: reportFilter)
                    .frame(minHeight: 180)
            } else {
                Text("Cần quyền Screen Time để xem số liệu này.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ladderCard: some View {
        CardView(title: "Thang can thiệp", systemImage: "arrow.up.right.circle") {
            LadderView(ladder: viewModel.ladder, reachedMinutes: viewModel.dayState.reachedMinutes)
        }
    }

    private var watchedCard: some View {
        CardView(title: "Đang theo dõi", systemImage: "square.grid.2x2") {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.selection.summary)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 10) {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Chọn ứng dụng", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isScreenTimeApproved)

                    if !viewModel.selection.isEmpty {
                        Button(role: .destructive) {
                            viewModel.clearSelection()
                        } label: {
                            Label("Xoá hết", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var controlsCard: some View {
        CardView(title: "Điều khiển", systemImage: "switch.2") {
            VStack(spacing: 14) {
                Toggle(isOn: Binding(
                    get: { viewModel.monitoringEnabled },
                    set: { viewModel.setMonitoring($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Giám sát hằng ngày")
                        Text("Lịch 00:00 → 23:59, tự lặp lại")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.awareMint)
                .disabled(!viewModel.isReadyToMonitor && !viewModel.monitoringEnabled)

                Divider()

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            showShieldPreview = true
                        } label: {
                            Label("Xem màn chắn", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            viewModel.applyShieldNow()
                        } label: {
                            Label("Chặn ngay", systemImage: "hand.raised")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.selection.isEmpty)
                    }

                    HStack(spacing: 10) {
                        Button {
                            viewModel.liftShieldNow()
                        } label: {
                            Label("Gỡ chặn", systemImage: "lock.open")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            viewModel.resetToday()
                        } label: {
                            Label("Reset hôm nay", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var demoCard: some View {
        CardView(
            title: "Chạy thử nhanh",
            systemImage: "play.circle",
            footnote: "Mô phỏng toàn bộ thang can thiệp trên đồng hồ tăng tốc: thông báo, Live Activity và màn chắn xuất hiện trong vài giây thay vì vài chục phút."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(viewModel.demo.isRunning
                         ? "Đang mô phỏng · phút \(viewModel.demo.simulatedMinutes)"
                         : "Chưa chạy")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if viewModel.demo.isRunning {
                        ProgressView()
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        viewModel.startDemo()
                    } label: {
                        Label("Bắt đầu", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.awareCalm)
                    .disabled(viewModel.demo.isRunning)

                    Button {
                        viewModel.stopDemo()
                    } label: {
                        Label("Dừng & xoá", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Shield preview sheet

    private var shieldPreviewSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ShieldPreviewView(presentation: previewPresentation)
                    Text("Đây là bản xem trước trong ứng dụng. Trên thực tế, màn hình này do ShieldConfigurationExtension vẽ và xuất hiện khi bạn mở ứng dụng bị chặn.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Màn chắn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { showShieldPreview = false }
                }
            }
        }
    }

    private var previewPresentation: ShieldPresentation {
        let stored = SharedStore.shieldPresentation
        if stored.generatedAt.timeIntervalSince1970 > 0 { return stored }
        return ShieldPresentation.make(
            minutesUsed: viewModel.settings.shieldThresholdMinutes,
            settings: viewModel.settings,
            snoozeCount: 0
        )
    }

    // MARK: - Helpers

    private func tone(for level: InterventionLevel) -> StatusPill.Tone {
        switch level {
        case .none: return .good
        case .notice: return .neutral
        case .warning: return .warn
        case .shield: return .bad
        }
    }

    private static func todayFilter() -> DeviceActivityFilter {
        DeviceActivityFilter(
            segment: .daily(
                during: Calendar.current.dateInterval(of: .day, for: Date())
                    ?? DateInterval(start: Date(), duration: 86_400)
            ),
            users: .all,
            devices: .all
        )
    }
}
