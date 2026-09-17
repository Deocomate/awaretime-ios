import FamilyControls
import SwiftUI

/// Configuration for the three levels plus the shield behaviour (spec §3.1).
struct SettingsView: View {

    @EnvironmentObject private var viewModel: UsageViewModel

    @State private var draft = InterventionSettings.default
    @State private var showResetConfirm = false
    @State private var showDiagnostics = false

    var body: some View {
        NavigationStack {
            Form {
                thresholdsSection
                shieldSection
                channelsSection
                permissionsSection
                dangerSection
                aboutSection
            }
            .navigationTitle("Cài đặt")
            .onAppear { draft = viewModel.settings }
            .onChange(of: draft) { newValue in
                viewModel.apply(settings: newValue)
                // `apply` sorts the levels; reflect that back into the pickers.
                if viewModel.settings != newValue { draft = viewModel.settings }
            }
            .sheet(isPresented: $showDiagnostics) {
                DiagnosticsView()
            }
            .confirmationDialog(
                "Xoá toàn bộ dữ liệu AwareTime?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Xoá tất cả", role: .destructive) {
                    viewModel.resetEverything()
                    draft = .default
                }
                Button("Huỷ", role: .cancel) {}
            } message: {
                Text("Lựa chọn ứng dụng, mốc thời gian, lịch sử và màn chắn sẽ bị xoá. Không thể hoàn tác.")
            }
        }
    }

    // MARK: - Sections

    private var thresholdsSection: some View {
        Section {
            picker(
                title: "Mức 1 · Nhắc nhẹ",
                selection: $draft.notificationThresholdMinutes,
                values: InterventionSettings.allowedThresholds,
                suffix: "phút"
            )
            picker(
                title: "Mức 2 · Cảnh báo",
                selection: $draft.warningThresholdMinutes,
                values: InterventionSettings.allowedThresholds,
                suffix: "phút"
            )
            picker(
                title: "Mức 3 · Màn chắn",
                selection: $draft.shieldThresholdMinutes,
                values: InterventionSettings.allowedThresholds,
                suffix: "phút"
            )
        } header: {
            Text("Mốc thời gian")
        } footer: {
            Text("Các mốc luôn được sắp xếp tăng dần. Nếu bạn đặt mức thấp hơn mức trước, AwareTime sẽ tự nâng lên 1 phút.")
        }
    }

    private var shieldSection: some View {
        Section {
            Toggle("Bật màn chắn ở mức 3", isOn: $draft.shieldEnabled)

            picker(
                title: "Gia hạn mỗi lần",
                selection: $draft.snoozeMinutes,
                values: InterventionSettings.allowedSnoozes,
                suffix: "phút"
            )
            .disabled(!draft.shieldEnabled)

            picker(
                title: "Chờ trước khi gỡ",
                selection: $draft.continueDelaySeconds,
                values: InterventionSettings.allowedDelays,
                suffix: "giây"
            )
            .disabled(!draft.shieldEnabled)

            Toggle("Hỏi một bài toán nhỏ", isOn: $draft.requiresMathChallenge)
                .disabled(!draft.shieldEnabled)

            Stepper(
                value: $draft.maxSnoozesPerDay,
                in: 0...12
            ) {
                HStack {
                    Text("Số lần gia hạn/ngày")
                    Spacer()
                    Text(draft.maxSnoozesPerDay == 0 ? "Không giới hạn" : "\(draft.maxSnoozesPerDay)")
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!draft.shieldEnabled)

            Picker("Sau khi vượt cửa", selection: $draft.unlockBehavior) {
                ForEach(ShieldUnlockBehavior.allCases) { behavior in
                    Text(behavior.title).tag(behavior)
                }
            }
            .disabled(!draft.shieldEnabled)
        } header: {
            Text("Màn chắn")
        } footer: {
            Text(draft.unlockBehavior.explanation)
        }
    }

    private var channelsSection: some View {
        Section {
            Toggle("Thông báo cục bộ", isOn: $draft.notificationsEnabled)
            Toggle("Live Activity / Dynamic Island", isOn: $draft.liveActivityEnabled)

            if draft.liveActivityEnabled {
                HStack {
                    Text("Trạng thái")
                    Spacer()
                    StatusPill(
                        text: viewModel.liveActivityRunning ? "Đang chạy" : "Chưa chạy",
                        tone: viewModel.liveActivityRunning ? .good : .neutral
                    )
                }
                Button("Bật Live Activity ngay") { viewModel.startLiveActivity() }
                Button("Kết thúc Live Activity", role: .destructive) { viewModel.endLiveActivity() }
            }
        } header: {
            Text("Kênh cảnh báo")
        } footer: {
            Text("Live Activity chỉ khởi động được khi AwareTime đang mở. Sau đó các extension sẽ cập nhật nội dung.")
        }
    }

    private var permissionsSection: some View {
        Section("Quyền") {
            HStack {
                Text("Screen Time")
                Spacer()
                StatusPill(
                    text: viewModel.screenTimeStatus.vietnameseTitle,
                    tone: viewModel.isScreenTimeApproved ? .good : .warn
                )
            }
            if !viewModel.isScreenTimeApproved {
                Button("Cấp quyền Screen Time") {
                    Task { await viewModel.requestScreenTimeAccess() }
                }
            }

            HStack {
                Text("Thông báo")
                Spacer()
                StatusPill(
                    text: viewModel.notificationStatus == .authorized ? "Đã bật" : "Chưa bật",
                    tone: viewModel.notificationStatus == .authorized ? .good : .warn
                )
            }
            Button("Gửi thông báo thử") { viewModel.sendTestNotification() }
        }
    }

    private var dangerSection: some View {
        Section("Bảo trì") {
            Button("Đưa các mốc về mặc định") {
                viewModel.resetSettings()
                draft = viewModel.settings
            }
            Button("Xoá lịch sử sự kiện") { viewModel.clearHistory() }
            Button("Xoá toàn bộ dữ liệu", role: .destructive) { showResetConfirm = true }
        }
    }

    private var aboutSection: some View {
        Section {
            Button("Thông tin kỹ thuật") { showDiagnostics = true }
            HStack {
                Text("Phiên bản")
                Spacer()
                Text(Self.versionString)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Về AwareTime")
        } footer: {
            Text("Mọi dữ liệu Screen Time được xử lý ngay trên thiết bị. AwareTime không gửi gì ra ngoài.")
        }
    }

    // MARK: - Helpers

    private func picker(
        title: String,
        selection: Binding<Int>,
        values: [Int],
        suffix: String
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(values, id: \.self) { value in
                Text(value == 0 ? "Không chờ" : "\(value) \(suffix)").tag(value)
            }
        }
    }

    static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// Shows the values that usually explain a misconfigured build.
struct DiagnosticsView: View {

    @EnvironmentObject private var viewModel: UsageViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("App Group") {
                    row("Identifier", AppGroup.identifier)
                    row("Truy cập được", AppGroup.isConfigured ? "Có" : "KHÔNG")
                }
                Section("Bundle") {
                    row("Bundle id", Bundle.main.bundleIdentifier ?? "—")
                    row("Phiên bản", SettingsView.versionString)
                    row("Môi trường", ProvisioningProfileInspector.isSimulator ? "Simulator" : "Thiết bị thật")
                }

                // The usual reason Screen Time refuses to talk to the app.
                Section {
                    HStack {
                        Text("Family Controls")
                        Spacer()
                        StatusPill(
                            text: familyControlsText,
                            systemImage: familyControlsSymbol,
                            tone: familyControlsTone
                        )
                    }
                    if let profile = ProvisioningProfileInspector.profile {
                        row("Profile", profile.name ?? "—")
                        row("Team", profile.teamIdentifier ?? "—")
                        row("Loại", profile.isDevelopment ? "Development" : "Distribution / Ad-hoc")
                        if let expiry = profile.expirationDate {
                            row("Hết hạn", AwareTimeFormat.dayAndClock(expiry) + (profile.isExpired ? " (ĐÃ HẾT)" : ""))
                        }
                        row("Time-Sensitive", profile.hasTimeSensitiveNotifications ? "Có" : "Không")
                        row("App Groups", profile.appGroups.isEmpty ? "—" : profile.appGroups.joined(separator: "\n"))
                    } else {
                        row("Provisioning profile", "Không đọc được")
                    }
                } header: {
                    Text("Entitlement của bản build")
                } footer: {
                    Text(entitlementFooter)
                }
                Section("Screen Time") {
                    row("Quyền", viewModel.screenTimeStatus.vietnameseTitle)
                    row("Lịch đã cài", viewModel.isScheduleInstalled ? "Có" : "Không")
                    row("Mục theo dõi", "\(viewModel.selection.watchedCount)")
                }
                Section("Hôm nay") {
                    row("Mức", viewModel.dayState.level.title)
                    row("Phút ghi nhận", "\(viewModel.dayState.reachedMinutes)")
                    row("Đang chặn", viewModel.dayState.shieldActive ? "Có" : "Không")
                    row("Số lần gia hạn", "\(viewModel.dayState.snoozeCount)")
                    if let snooze = viewModel.dayState.snoozeUntil {
                        row("Gia hạn đến", AwareTimeFormat.timestamp(snooze))
                    }
                }
            }
            .navigationTitle("Thông tin kỹ thuật")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }

    // MARK: - Family Controls entitlement

    private var familyControlsText: String {
        switch ProvisioningProfileInspector.familyControlsState {
        case .granted: return "Có trong profile"
        case .missing: return "THIẾU"
        case .indeterminate: return "Không xác định"
        }
    }

    private var familyControlsSymbol: String {
        switch ProvisioningProfileInspector.familyControlsState {
        case .granted: return "checkmark"
        case .missing: return "xmark"
        case .indeterminate: return "questionmark"
        }
    }

    private var familyControlsTone: StatusPill.Tone {
        switch ProvisioningProfileInspector.familyControlsState {
        case .granted: return .good
        case .missing: return .bad
        case .indeterminate: return .warn
        }
    }

    private var entitlementFooter: String {
        if ProvisioningProfileInspector.isSimulator {
            return "Simulator không hỗ trợ Screen Time API — việc cấp quyền sẽ luôn thất bại. Dùng “Chạy thử nhanh” để kiểm tra giao diện."
        }
        switch ProvisioningProfileInspector.familyControlsState {
        case .granted:
            return "Bản build có quyền nói chuyện với tiến trình Screen Time."
        case .missing:
            return "Đây chính là nguyên nhân của lỗi “Không thể liên lạc với ứng dụng trợ giúp”. Phải ký lại app bằng provisioning profile có bật Family Controls."
        case .indeterminate:
            return "Không có embedded.mobileprovision — thường là bản App Store hoặc bản chạy trên Simulator."
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer(minLength: 12)
            Text(value)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
