BẢN THIẾT KẾ YÊU CẦU KỸ THUẬT (PRD & TECHNICAL SPEC)
Tên dự án: AwareTime
Nền tảng: iOS Native (iOS 16.0+)
Mục tiêu: Ứng dụng theo dõi và cảnh báo thời gian sử dụng các ứng dụng cụ thể nhằm tăng cường nhận thức người dùng, thay thế cơ chế overlay bằng Screen Time API và Live Activities.

1. NGĂN XẾP CÔNG NGHỆ (TECH STACK)
Ngôn ngữ: Swift

Giao diện: SwiftUI

Kiến trúc: MVVM

Framework cốt lõi:

FamilyControls: Cấp quyền truy cập Screen Time.

DeviceActivity: Theo dõi ngưỡng thời gian sử dụng ngầm.

ManagedSettings: Áp dụng Shield UI (Màn hình chắn).

ActivityKit: Hiển thị Live Activities / Dynamic Island.

UserNotifications: Gửi cảnh báo Local Notification.

2. LUỒNG NGƯỜI DÙNG VÀ CƠ CHẾ HOẠT ĐỘNG (APP FLOW)
2.1. Cài đặt và Phân quyền (Onboarding)

Yêu cầu quyền truy cập Notification.

Yêu cầu quyền AuthorizationCenter.shared.requestAuthorization (Family Controls).

Giao diện chọn danh sách ứng dụng cần theo dõi thông qua FamilyActivityPicker.

2.2. Cơ chế Giám sát (Monitoring)

Sử dụng DeviceActivitySchedule để tạo lịch trình giám sát hàng ngày (ví dụ: 00:00 - 23:59).

Sử dụng DeviceActivityMonitor extension để lắng nghe các sự kiện khi ứng dụng trong danh sách đạt ngưỡng thời gian.

2.3. Cơ chế Cảnh báo leo thang (Escalating Interventions)

Mức 1 (Ví dụ: 15 phút): Gửi Local Notification với nội dung cảnh báo nhẹ nhàng.

Mức 2 (Ví dụ: 30 phút): Cập nhật Live Activity/Dynamic Island cảnh báo màu vàng/đỏ.

Mức 3 (Ví dụ: 45 phút): Kích hoạt ManagedSettingsStore để áp dụng Shield lên ứng dụng đang dùng.

2.4. Cơ chế Shield UI (Màn hình chắn)

Tạo ShieldConfigurationDataSource extension để tùy chỉnh giao diện màn hình chặn (Icon AwareTime, Tiêu đề cảnh báo số phút đã dùng).

Tạo ShieldActionDelegate extension:

Cung cấp 2 lựa chọn: "Đóng ứng dụng" hoặc "Tiếp tục sử dụng".

Nếu chọn "Tiếp tục sử dụng", yêu cầu thời gian chờ (delay 5 giây) hoặc giải một bài toán nhỏ trước khi gỡ Shield tạm thời (thông qua việc xóa token khỏi ManagedSettingsStore).

3. KIẾN TRÚC MODULE (DÀNH CHO DEV AGENT)
3.1. Main App Target

AwareTimeApp.swift: Chứa logic khởi tạo, kiểm tra quyền FamilyControls.

MainView.swift: Giao diện chính (Dashboard xem thống kê, nút mở ActivityPicker).

SettingsView.swift: Cấu hình các mốc thời gian cảnh báo (Mức 1, 2, 3).

UsageViewModel.swift: Quản lý logic lưu trữ cấu hình (Sử dụng AppStorage hoặc UserDefaults).

3.2. Device Activity Monitor Extension

Lắng nghe các sự kiện: eventDidReachThreshold, intervalDidStart, intervalDidEnd.

Thực thi logic bắn Notification và đẩy cấu hình Shield vào ManagedSettingsStore.

3.3. Shield Configuration & Action Extensions

ShieldConfigurationExtension: Trả về giao diện (UI) tùy chỉnh cho màn hình chặn.

ShieldActionExtension: Xử lý logic khi người dùng bấm nút trên màn hình chặn.

3.4. Widget Extension (Live Activities)

Hiển thị Widget trên Lock Screen và Dynamic Island.

Cập nhật trạng thái thời gian đếm ngược/cảnh báo thông qua ActivityKit.

4. MÔ HÌNH DỮ LIỆU CỐT LÕI (DATA STRUCTURE)
Swift
import Foundation
import FamilyControls
import ManagedSettings

struct InterventionSettings: Codable {
    var notificationThresholdMinutes: Int // Mốc gửi thông báo
    var shieldThresholdMinutes: Int       // Mốc hiển thị Shield
}

class AppState: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    @Published var settings = InterventionSettings(notificationThresholdMinutes: 15, shieldThresholdMinutes: 45)
    
    // Lưu FamilyActivitySelection vào UserDefaults để tái sử dụng
    func saveSelection() { ... }
    func loadSelection() { ... }
}
5. YÊU CẦU TRIỂN KHAI CHO AGENT
Phase 1: Khởi tạo project, thiết lập App Group (để share dữ liệu giữa App và các Extensions) và cấu hình các Capabilities (Family Controls, Push Notifications, Time Sensitive Notifications).

Phase 2: Triển khai Main App UI (SwiftUI) và FamilyActivityPicker để lấy danh sách token của các ứng dụng cần theo dõi.

Phase 3: Tạo DeviceActivityMonitor extension. Cài đặt lịch trình (DeviceActivitySchedule) và lắng nghe sự kiện đạt ngưỡng thời gian.

Phase 4: Tích hợp UserNotifications trong Extension để gửi cảnh báo.

Phase 5: Tạo ShieldConfiguration và ShieldAction extensions. Xử lý logic cho phép "Tiếp tục sử dụng" (gỡ chặn tạm thời thêm 15 phút).

Phase 6 (Optional/Tối ưu): Triển khai Live Activity hiển thị cảnh báo ngầm ra Lock Screen / Dynamic Island.