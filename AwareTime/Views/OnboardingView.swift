import FamilyControls
import SwiftUI

/// Onboarding + permissions (spec §2.1).
struct OnboardingView: View {

    @EnvironmentObject private var viewModel: UsageViewModel

    private enum Step: Int, CaseIterable {
        case welcome, notifications, screenTime, pickApps, thresholds

        var title: String {
            switch self {
            case .welcome: return "Chào mừng"
            case .notifications: return "Thông báo"
            case .screenTime: return "Screen Time"
            case .pickApps: return "Ứng dụng theo dõi"
            case .thresholds: return "Mốc cảnh báo"
            }
        }
    }

    @State private var step: Step = .welcome
    @State private var showPicker = false
    @State private var draftSettings = InterventionSettings.default

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let banner = viewModel.banner {
                            BannerView(banner: banner) { viewModel.banner = nil }
                        }
                        content
                    }
                    .padding(20)
                }

                footer
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Bỏ qua") { viewModel.completeOnboarding() }
                        .font(.footnote)
                }
            }
            .sheet(isPresented: $showPicker) {
                AppPickerView(initialSelection: viewModel.selection) { selection in
                    viewModel.updateSelection(selection)
                }
            }
            .onAppear { draftSettings = viewModel.settings }
        }
    }

    // MARK: - Chrome

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Color.awareCalm : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: advance) {
                Text(primaryButtonTitle)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.awareCalm)
            .controlSize(.large)
            .disabled(viewModel.isWorking)

            if step != .welcome {
                Button("Quay lại") { retreat() }
                    .font(.footnote)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .padding(.top, 8)
        .background(.bar)
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome: return "Bắt đầu"
        case .notifications: return viewModel.notificationStatus == .authorized ? "Tiếp tục" : "Cho phép thông báo"
        case .screenTime: return viewModel.isScreenTimeApproved ? "Tiếp tục" : "Cấp quyền Screen Time"
        case .pickApps: return viewModel.selection.isEmpty ? "Chọn ứng dụng" : "Tiếp tục"
        case .thresholds: return "Hoàn tất"
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            welcomeStep
        case .notifications:
            notificationsStep
        case .screenTime:
            screenTimeStep
        case .pickApps:
            pickAppsStep
        case .thresholds:
            thresholdsStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "hourglass.badge.plus")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.awareCalm)

            Text("AwareTime giúp bạn *nhận ra* mình đang dùng gì, bao lâu")
                .font(.title2.weight(.bold))

            Text("Không chặn cứng ngay từ đầu. AwareTime leo thang nhẹ nhàng theo ba mức, để bạn tự quyết định.")
                .foregroundStyle(.secondary)

            CardView(title: "Ba mức can thiệp", systemImage: "arrow.up.right.circle") {
                LadderView(ladder: MonitoringPlan.ladderDescription(settings: .default), reachedMinutes: 0)
            }

            CardView(
                title: "Quyền cần thiết",
                systemImage: "lock.shield",
                footnote: "AwareTime xử lý mọi thứ ngay trên thiết bị. Dữ liệu Screen Time không rời khỏi iPhone của bạn."
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Thông báo — để nhắc bạn đúng lúc", systemImage: "bell")
                    Label("Screen Time — để đo thời gian dùng app", systemImage: "hourglass")
                }
                .font(.footnote)
            }
        }
    }

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cho phép AwareTime gửi thông báo")
                .font(.title2.weight(.bold))
            Text("Mức 1 là một nhắc nhở nhẹ. Mức 2 dùng thông báo “Time Sensitive” để xuyên qua chế độ Tập trung.")
                .foregroundStyle(.secondary)

            CardView(title: "Trạng thái hiện tại", systemImage: "bell.badge") {
                HStack {
                    Text("Thông báo")
                    Spacer()
                    StatusPill(
                        text: notificationStatusText,
                        systemImage: viewModel.notificationStatus == .authorized ? "checkmark" : "exclamationmark",
                        tone: viewModel.notificationStatus == .authorized ? .good : .warn
                    )
                }
                .font(.subheadline)
            }
        }
    }

    private var screenTimeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kết nối Screen Time")
                .font(.title2.weight(.bold))
            Text("iOS sẽ hỏi bạn xác nhận. AwareTime chỉ nhận về các “token” ẩn danh — không đọc được bạn xem gì trong ứng dụng.")
                .foregroundStyle(.secondary)

            CardView(title: "Trạng thái quyền", systemImage: "hourglass") {
                HStack {
                    Text("Family Controls")
                    Spacer()
                    StatusPill(
                        text: viewModel.screenTimeStatus.vietnameseTitle,
                        systemImage: viewModel.isScreenTimeApproved ? "checkmark" : "exclamationmark",
                        tone: viewModel.isScreenTimeApproved ? .good : .warn
                    )
                }
                .font(.subheadline)
            }

            if !viewModel.appGroupConfigured {
                CardView(
                    title: "Thiếu App Group",
                    systemImage: "exclamationmark.triangle",
                    footnote: "Bản build này chưa bật App Group nên ứng dụng và các extension không chia sẻ được dữ liệu. Xem docs/BUILD.md."
                ) {
                    EmptyView()
                }
            }
        }
    }

    private var pickAppsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bạn muốn theo dõi ứng dụng nào?")
                .font(.title2.weight(.bold))
            Text("Chọn những ứng dụng dễ làm bạn mất thời gian nhất. Có thể chọn cả danh mục hoặc website.")
                .foregroundStyle(.secondary)

            CardView(title: "Đang theo dõi", systemImage: "square.grid.2x2") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.selection.summary)
                        .font(.subheadline.weight(.medium))
                    Button {
                        showPicker = true
                    } label: {
                        Label(
                            viewModel.selection.isEmpty ? "Mở danh sách ứng dụng" : "Chỉnh sửa lựa chọn",
                            systemImage: "plus.circle"
                        )
                    }
                    .disabled(!viewModel.isScreenTimeApproved)
                }
            }

            if !viewModel.isScreenTimeApproved {
                Text("Cần cấp quyền Screen Time ở bước trước để mở được danh sách ứng dụng.")
                    .font(.footnote)
                    .foregroundStyle(Color.awareAmber)
            }
        }
    }

    private var thresholdsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Đặt mốc cho riêng bạn")
                .font(.title2.weight(.bold))
            Text("Có thể đổi bất cứ lúc nào trong tab Cài đặt.")
                .foregroundStyle(.secondary)

            CardView(title: "Mốc thời gian", systemImage: "timer") {
                VStack(spacing: 4) {
                    ThresholdStepper(
                        title: "Mức 1 · Nhắc nhẹ",
                        minutes: draftSettings.notificationThresholdMinutes,
                        tint: .awareCalm
                    ) { draftSettings.notificationThresholdMinutes = $0 }

                    Divider()

                    ThresholdStepper(
                        title: "Mức 2 · Cảnh báo",
                        minutes: draftSettings.warningThresholdMinutes,
                        tint: .awareAmber
                    ) { draftSettings.warningThresholdMinutes = $0 }

                    Divider()

                    ThresholdStepper(
                        title: "Mức 3 · Màn chắn",
                        minutes: draftSettings.shieldThresholdMinutes,
                        tint: .awareAlert
                    ) { draftSettings.shieldThresholdMinutes = $0 }
                }
            }

            CardView(title: "Xem trước", systemImage: "eye") {
                LadderView(
                    ladder: MonitoringPlan.ladderDescription(settings: draftSettings),
                    reachedMinutes: 0
                )
            }
        }
    }

    private var notificationStatusText: String {
        switch viewModel.notificationStatus {
        case .authorized, .provisional, .ephemeral: return "Đã bật"
        case .denied: return "Đã tắt"
        case .notDetermined: return "Chưa hỏi"
        @unknown default: return "Không rõ"
        }
    }

    // MARK: - Navigation

    private func advance() {
        switch step {
        case .welcome:
            step = .notifications

        case .notifications:
            if viewModel.notificationStatus == .authorized {
                step = .screenTime
            } else {
                Task {
                    await viewModel.requestNotificationAccess()
                    if viewModel.notificationStatus == .authorized { step = .screenTime }
                }
            }

        case .screenTime:
            if viewModel.isScreenTimeApproved {
                step = .pickApps
            } else {
                Task {
                    await viewModel.requestScreenTimeAccess()
                    if viewModel.isScreenTimeApproved { step = .pickApps }
                }
            }

        case .pickApps:
            if viewModel.selection.isEmpty {
                showPicker = true
            } else {
                step = .thresholds
            }

        case .thresholds:
            viewModel.apply(settings: draftSettings)
            viewModel.completeOnboarding()
            if viewModel.isReadyToMonitor {
                viewModel.startMonitoring()
            }
        }
    }

    private func retreat() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }
}

/// Minute picker used by onboarding and the settings screen.
struct ThresholdStepper: View {

    let title: String
    let minutes: Int
    let tint: Color
    let onChange: (Int) -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.subheadline)
            Spacer(minLength: 8)
            Picker(title, selection: Binding(get: { minutes }, set: onChange)) {
                ForEach(InterventionSettings.allowedThresholds, id: \.self) { value in
                    Text("\(value) phút").tag(value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
