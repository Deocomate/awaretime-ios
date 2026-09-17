# Kịch bản kiểm thử AwareTime

## A. Kiểm tra nhanh (≈ 1 phút, không cần chờ Screen Time)

Dùng nút **Chạy thử nhanh** ở tab *Hôm nay*. Nó phát lại đúng chuỗi trạng thái
thật trên đồng hồ tăng tốc (1 phút sử dụng ≈ 0,4 giây thật).

1. Mở app → tab **Hôm nay** → **Chạy thử nhanh → Bắt đầu**.
2. Trong ~20 giây, lần lượt quan sát:
   * mốc 15 → thông báo "Bạn đã dùng 15 phút";
   * mốc 30 → thông báo *Time Sensitive* + Live Activity/Dynamic Island chuyển
     màu hổ phách;
   * mốc 45 → thông báo "AwareTime đã tạm chặn", thanh tiến trình đầy, huy hiệu
     **Đang chặn** xuất hiện.
3. Bấm **Xem màn chắn** để xem đúng giao diện mà
   `ShieldConfigurationExtension` sẽ vẽ.
4. Tab **Lịch sử** phải có đủ các dòng `[Mô phỏng] Mức 1/2/3`.
5. **Dừng & xoá** để đưa trạng thái về sạch.

Bước này chạy được cả trên Simulator và trên IPA chưa có entitlement Family
Controls — dùng để xác nhận thông báo, Live Activity và giao diện.

---

## B. Kiểm thử thật đầu-cuối (cần iPhone + entitlement)

### B1. Onboarding

| Bước | Kỳ vọng |
|---|---|
| Mở app lần đầu | Hiện 5 bước onboarding |
| Bấm **Cho phép thông báo** | iOS hỏi quyền; sau đó huy hiệu chuyển "Đã bật" |
| Bấm **Cấp quyền Screen Time** | iOS hiện hộp thoại Screen Time; sau đó huy hiệu "Đã cấp quyền" |
| Bấm **Chọn ứng dụng** | `FamilyActivityPicker` mở ra, chọn được app/danh mục/website |
| Bấm **Xong** rồi **Hoàn tất** | Vào dashboard, toggle *Giám sát hằng ngày* đã bật, huy hiệu **Lịch đã cài** xuất hiện |

### B2. Giám sát + mức 1 và 2

Đặt mốc thấp cho dễ test: **Cài đặt → Mức 1 = 1 phút, Mức 2 = 2 phút,
Mức 3 = 5 phút**.

1. Thoát AwareTime, dùng ứng dụng đã chọn liên tục.
2. Sau ~1 phút: nhận thông báo nhắc nhẹ.
3. Sau ~2 phút: nhận thông báo Time Sensitive; kiểm tra Dynamic Island đổi màu.
4. Mở lại AwareTime → tab **Lịch sử** có `Mức 1 — đã dùng 1 phút` và
   `Mức 2 — đã dùng 2 phút`.

> DeviceActivity tính thời gian theo mẫu của hệ thống nên sự kiện có thể trễ
> 1–2 phút so với đồng hồ. Đó là hành vi bình thường của iOS.

### B3. Màn chắn và nút "Tiếp tục sử dụng"

1. Dùng tiếp đến mốc mức 3 (hoặc mở AwareTime bấm **Chặn ngay**).
2. Mở ứng dụng bị theo dõi → màn chắn AwareTime hiện ra, tiêu đề có tên ứng
   dụng và số phút đã dùng.
3. Bấm **Đóng ứng dụng** → ứng dụng đóng. Lịch sử ghi
   `Bạn đã chọn đóng ứng dụng`.
4. Mở lại, bấm **Tiếp tục sử dụng** → sau 5 giây màn chắn được gỡ. Lịch sử ghi
   `Gỡ chặn tạm thời 15 phút`, dashboard hiện huy hiệu **Gia hạn đến HH:mm**.
5. Dùng hết thời gian gia hạn → màn chắn tự bật lại và có thông báo
   `Hết thời gian gia hạn`.

Nếu sau khi bấm **Tiếp tục sử dụng** mà màn chắn vẫn nằm đó: vào
**Cài đặt → Màn chắn → Sau khi vượt cửa** và thử giá trị còn lại. Mặc định
(*Đóng rồi mở lại*) là cách hoạt động ổn định trên mọi phiên bản iOS.

### B4. Bài toán nhỏ

1. **Cài đặt → Màn chắn → bật "Hỏi một bài toán nhỏ"**.
2. **Chặn ngay**, mở ứng dụng bị chặn.
3. Màn chắn hiện câu hỏi, hai nút là hai đáp án.
4. Chọn **sai** → ứng dụng đóng, lịch sử ghi `Trả lời sai`. Mở lại phải thấy
   **câu hỏi khác**.
5. Chọn **đúng** → chờ 5 giây → được gia hạn.

### B5. Giới hạn số lần gia hạn

1. Đặt **Số lần gia hạn/ngày = 1**.
2. Gia hạn một lần.
3. Lần chặn tiếp theo, màn chắn chỉ còn **một** nút *Đóng ứng dụng* và phụ đề
   ghi đã dùng hết lượt gia hạn.

### B6. Live Activity / Dynamic Island

1. Bật **Cài đặt → Live Activity**, bấm **Bật Live Activity ngay**.
2. Khoá máy → thẻ AwareTime xuất hiện trên Lock Screen với thanh tiến trình.
3. Trên iPhone 14 Pro trở lên: thu nhỏ app, xem Dynamic Island (compact hiện
   icon + số phút; nhấn giữ để xem dạng mở rộng).
4. Khi đạt mức 2/3, màu đổi sang hổ phách/đỏ.

### B7. Widget Home Screen

Nhấn giữ Home Screen → **+** → AwareTime → *Trạng thái AwareTime*. Widget phải
hiện đúng số phút, mức và mốc chặn.

### B8. Sang ngày mới

1. Đặt trước thời gian hệ thống đến gần nửa đêm, hoặc chỉ cần đợi.
2. Sau 00:00: `intervalDidStart` chạy, bộ đếm về 0, mọi màn chắn được gỡ, lịch
   sử ghi `Bắt đầu ngày theo dõi mới`.
3. Có thể mô phỏng bằng nút **Reset hôm nay**.

### B9. Đổi lựa chọn / mốc khi đang giám sát

1. Đang bật giám sát, mở picker và thêm một ứng dụng → bấm **Xong**.
2. **Cài đặt → Thông tin kỹ thuật → Lịch đã cài** vẫn phải là "Có" (app tự cài
   lại `DeviceActivitySchedule` với danh sách mới).
3. Đổi Mức 2 xuống thấp hơn Mức 1 → giá trị tự được nâng lên (mốc luôn tăng dần).

---

## C. Kiểm tra cấu hình build

```bash
python3 Tools/validate_xcodeproj.py
```

Báo cáo số object, số file, số extension được embed và sẽ **thất bại** nếu:

* `project.pbxproj` sai cú pháp,
* có tham chiếu trỏ tới object không tồn tại,
* có file trong project mà không có trên đĩa,
* có file `.swift` nào không được biên dịch vào bất kỳ target nào,
* app không embed đủ 5 extension.

CI chạy đúng lệnh này, cộng thêm một bản build Simulator và một bản build thiết
bị chưa ký.
