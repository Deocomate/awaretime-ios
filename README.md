# AwareTime

Ứng dụng iOS native (SwiftUI + MVVM) theo dõi thời gian dùng các ứng dụng cụ thể
và can thiệp leo thang theo ba mức, dựa trên **Screen Time API** thay vì overlay.

Triển khai theo `docs/spec.md`, đầy đủ Phase 1 → Phase 6.

---

## Trạng thái các Phase

| Phase | Nội dung | Trạng thái |
|---|---|---|
| 1 | Project, App Group, capabilities (Family Controls, Time-Sensitive Notifications) | ✅ |
| 2 | Main app UI + `FamilyActivityPicker` | ✅ |
| 3 | `DeviceActivityMonitor` extension + `DeviceActivitySchedule` | ✅ |
| 4 | `UserNotifications` trong extension | ✅ |
| 5 | `ShieldConfiguration` + `ShieldAction`, gia hạn tạm thời | ✅ |
| 6 | Live Activity / Dynamic Island | ✅ |
| + | `DeviceActivityReport` extension (thống kê thật trên dashboard) | ✅ |

## Cấu trúc target

| Target | Loại | Vai trò |
|---|---|---|
| `AwareTime` | App | Onboarding, dashboard, cài đặt, lịch sử |
| `DeviceActivityMonitorExtension` | App extension | Nhận sự kiện ngưỡng, bắn thông báo, áp màn chắn |
| `ShieldConfigurationExtension` | App extension | Vẽ màn hình chắn |
| `ShieldActionExtension` | App extension | Xử lý 2 nút trên màn hình chắn |
| `DeviceActivityReportExtension` | App extension | Render số liệu Screen Time trong app |
| `AwareTimeWidget` | App extension | Live Activity + Dynamic Island + widget Home Screen |

Code dùng chung nằm trong `Shared/` và được biên dịch trực tiếp vào từng target
(không dùng framework động, để các extension khởi động nhanh và nhẹ).

## Thang can thiệp

| Mức | Mặc định | Hành động |
|---|---|---|
| 1 | 15 phút | Local notification nhắc nhẹ |
| 2 | 30 phút | Thông báo *Time Sensitive* + Live Activity/Dynamic Island đổi sang màu hổ phách |
| 3 | 45 phút | `ManagedSettingsStore` áp màn chắn lên các ứng dụng đang theo dõi |

Trên màn chắn có hai lựa chọn:

* **Đóng ứng dụng** — ứng dụng đóng lại.
* **Tiếp tục sử dụng** — chờ 5 giây (cấu hình được) rồi gỡ chắn thêm 15 phút.
  Nếu bật “Hỏi một bài toán nhỏ”, hai nút trở thành hai đáp án; chọn sai thì
  ứng dụng đóng lại và câu hỏi mới được tạo cho lần sau.

Hết thời gian gia hạn, màn chắn tự bật lại: app đăng ký sẵn một loạt mốc
“re-shield” tại `mốc chặn + n × thời gian gia hạn` (xem `MonitoringPlan`), vì
extension của màn chắn không thể tự đặt lại `DeviceActivitySchedule`.

## Bắt đầu nhanh

```bash
git clone https://github.com/deocomate/awaretime-ios.git
cd awaretime-ios
open AwareTime.xcodeproj      # mở trực tiếp, không cần cài thêm gì
```

Trong Xcode: chọn target `AwareTime` → tab **Signing & Capabilities** → chọn
Team của bạn, rồi ⌘R lên iPhone thật.

> Screen Time API **không hoạt động trên Simulator**. Trên Simulator app vẫn
> chạy được và bạn có thể dùng nút **Chạy thử nhanh** để xem toàn bộ luồng cảnh
> báo trên đồng hồ tăng tốc.

Chi tiết cấu hình, ký, và tải `.ipa`: **[docs/BUILD.md](docs/BUILD.md)**
Kịch bản kiểm thử: **[docs/TESTING.md](docs/TESTING.md)**
Kiến trúc và luồng dữ liệu: **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**

## Lấy file .ipa

Mỗi lần push, GitHub Actions (`.github/workflows/ios-build.yml`) build trên
macOS runner và upload **`awaretime-unsigned-ipa`** vào artifacts của workflow
run — tải về ngay từ tab Actions.

IPA đó **chưa được ký**, nên phải ký lại trước khi cài (Sideloadly / AltStore /
`ios-app-signer`). Nếu bạn có tài khoản Apple Developer, chạy
`workflow_dispatch` với tuỳ chọn *signed* (hoặc `make signed-ipa` trên máy Mac)
để lấy IPA ad-hoc cài trực tiếp. Cả hai cách được mô tả từng bước trong
`docs/BUILD.md`.

## Thay đổi bundle id / App Group

Sửa một chỗ duy nhất — `BUNDLE_ID_PREFIX` trong `Tools/generate_xcodeproj.py` —
rồi chạy `make project`. Tất cả 6 target và App Group (`group.<prefix>.awaretime`)
được cập nhật theo; code đọc App Group id từ `Info.plist` nên không cần sửa Swift.

## Lệnh hay dùng

```bash
make project      # sinh lại AwareTime.xcodeproj từ cây thư mục
make validate     # kiểm tra project.pbxproj (tham chiếu, file trên đĩa, embed phase)
make assets       # sinh lại app icon + icon màn chắn
make ipa          # build + đóng gói IPA chưa ký (cần macOS)
make signed-ipa   # build + export IPA ad-hoc đã ký (cần macOS + team id)
```

`AwareTime.xcodeproj` được sinh ra và **có commit trong repo**, nên mở Xcode là
dùng được ngay. Sau khi thêm/xoá/đổi tên file Swift, nhớ chạy `make project`
(CI sẽ báo lỗi nếu project bị lệch).

## Quyền riêng tư

Mọi dữ liệu Screen Time được xử lý ngay trên thiết bị. App không có code mạng,
không gửi gì ra ngoài. Token ứng dụng do iOS cấp là ẩn danh và chỉ có ý nghĩa
trong nội bộ App Group của AwareTime.
