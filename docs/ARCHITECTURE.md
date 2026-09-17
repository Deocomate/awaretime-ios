# Kiến trúc AwareTime

## Sơ đồ luồng

```
                    ┌──────────────────────────────┐
                    │   AwareTime (app, SwiftUI)   │
                    │  UsageViewModel  (MVVM)      │
                    └───┬──────────────────────┬───┘
      cài lịch giám sát │                      │ đọc/ghi
                        ▼                      ▼
        ┌───────────────────────────┐   ┌────────────────────────────┐
        │   DeviceActivityCenter    │   │  App Group UserDefaults    │
        │  startMonitoring(...)     │   │  settings / selection /    │
        └───────────┬───────────────┘   │  dayState / eventLog /     │
                    │ sự kiện ngưỡng    │  shieldPresentation        │
                    ▼                   └───┬──────────┬─────────┬───┘
   ┌────────────────────────────────┐       │          │         │
   │ DeviceActivityMonitorExtension │◀──────┘          │         │
   │  • UserNotifications           │                  │         │
   │  • ManagedSettingsStore.shield │                  │         │
   │  • cập nhật Live Activity      │                  │         │
   └────────────┬───────────────────┘                  │         │
                │ áp màn chắn                          │         │
                ▼                                      │         │
   ┌────────────────────────────────┐                  │         │
   │ ShieldConfigurationExtension   │◀─────────────────┘         │
   │  vẽ màn hình chắn              │                            │
   └────────────────────────────────┘                            │
   ┌────────────────────────────────┐                            │
   │ ShieldActionExtension          │◀───────────────────────────┘
   │  Đóng / Tiếp tục (+5s, +toán)  │
   └────────────────────────────────┘
   ┌────────────────────────────────┐   ┌────────────────────────────┐
   │ AwareTimeWidget                │   │ DeviceActivityReport       │
   │  Live Activity + Dynamic Island│   │  số liệu Screen Time thật  │
   └────────────────────────────────┘   └────────────────────────────┘
```

## Tại sao dùng App Group UserDefaults

Extension chạy trong process riêng, vòng đời rất ngắn và không thể gọi vào app.
App Group `UserDefaults` là kênh chia sẻ được Apple hỗ trợ, đồng bộ ngay và
không cần khởi tạo gì. `SharedStore` gói toàn bộ việc này lại thành các thuộc
tính có kiểu, còn `DayState.rolledOverIfNeeded()` bảo đảm mọi bên đều thấy trạng
thái của đúng ngày hôm nay.

App Group id được đọc từ `Info.plist` (khoá `AwareTimeAppGroupIdentifier`, giá
trị `$(APP_GROUP_ID)`), nên đổi bundle id prefix không phải sửa Swift.

## Vì sao màn chắn tự bật lại được

`ShieldActionExtension` không thể gọi `DeviceActivityCenter.startMonitoring`
một cách đáng tin cậy, nên không thể tự hẹn "15 phút nữa chặn lại". Thay vào
đó, khi app cài lịch giám sát, `MonitoringPlan.events(...)` đăng ký sẵn 8 mốc
`awaretime.reshield.n` tại `mốc chặn + n × thời gian gia hạn`. Mỗi lần một mốc
như vậy nổ, monitor extension gọi `ShieldController.reapplyIfSnoozeExpired()`:
nếu thời gian gia hạn đã hết thì màn chắn được áp lại, còn không thì bỏ qua.
App cũng chạy đúng hàm này mỗi lần quay lại foreground, nên trạng thái luôn tự
hội tụ.

## Vì sao bài toán được tạo lúc *áp* màn chắn

`ShieldConfigurationDataSource` chỉ được hỏi khi iOS cần vẽ màn chắn, và không
có API nào bảo đảm màn chắn sẽ vẽ lại giữa phiên. Vì vậy `ShieldPresentation`
(gồm tiêu đề, phụ đề, nhãn hai nút và câu hỏi nếu có) được tạo **ngay khi màn
chắn được áp** rồi ghi vào App Group. Nhờ đó:

* màn chắn không bao giờ hiển thị dữ liệu cũ;
* `ShieldActionExtension` biết chính xác nút nào là đáp án đúng;
* trả lời sai → đóng app + tạo câu hỏi mới, và câu hỏi mới chắc chắn được dùng
  vì lần sau iOS phải vẽ lại màn chắn từ đầu.

## Thống kê thời gian sử dụng

`DeviceActivityReportExtension` bị sandbox rất chặt: nó đọc được dữ liệu hoạt
động nhưng **không** được gửi dữ liệu ra ngoài process của nó, kể cả vào App
Group. Vì vậy dashboard *nhúng* view `DeviceActivityReport` do hệ thống render,
thay vì cố lấy một con số về rồi tự vẽ. Số phút hiển thị ở thẻ trạng thái là
mốc sự kiện gần nhất mà monitor extension ghi lại — hai nguồn này bổ sung cho
nhau.

## Các file dùng chung và target

`Shared/` được biên dịch trực tiếp vào từng target (không dùng framework động —
extension nhờ đó khởi động nhanh hơn và không phải nhúng thêm binary). Danh sách
file cho từng target nằm trong `Tools/generate_xcodeproj.py`:

| Nhóm | Nội dung | Vào target nào |
|---|---|---|
| `SHARED_CORE` | App Group, model, `SharedStore`, Live Activity attributes, palette, formatter | tất cả |
| `SHARED_FAMILY` | `SelectionStore`, `ShieldController` (cần FamilyControls/ManagedSettings) | app + 4 extension Screen Time |
| `SHARED_NOTIFICATIONS` | `NotificationScheduler` | app + monitor |
| `SHARED_MONITORING` | `MonitoringPlan` | app + monitor |
| `SHARED_REPORT` | `ReportContext` | app + report |

`AwareTimeWidget` chỉ nhận `SHARED_CORE`, nên nó **không** cần entitlement
Family Controls. Số mục đang theo dõi được cache thành một `Int`
(`SharedStore.watchedCount`) chỉ để widget khỏi phải giải mã token.

## Mô hình dữ liệu

| Kiểu | Vai trò |
|---|---|
| `InterventionSettings` | 3 mốc + hành vi màn chắn. Decode phòng vệ: khoá thiếu thì lấy mặc định |
| `InterventionLevel` | `.none < .notice < .warning < .shield` |
| `DayState` | Mức cao nhất hôm nay, số phút, đang chặn?, hạn gia hạn, số lần gia hạn |
| `ShieldPresentation` | Toàn bộ nội dung màn chắn, tạo lúc áp chắn |
| `MathChallenge` | Câu hỏi + hai đáp án + đáp án nào đúng |
| `InterventionEvent` | Một dòng lịch sử (giữ 120 dòng gần nhất) |
| `LadderStep` | Một bậc của thang can thiệp, để hiển thị |

## Xcode project được sinh tự động

`AwareTime.xcodeproj` không viết tay: `Tools/generate_xcodeproj.py` sinh ra
`project.pbxproj` với id ổn định (md5 của khoá mô tả), nên diff giữa hai lần
sinh đọc được. `Tools/validate_xcodeproj.py` phân tích lại file vừa sinh và
kiểm tra tính nhất quán; CI chạy cả hai và bắt lỗi nếu bản commit bị lệch.
