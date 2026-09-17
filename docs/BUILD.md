# Build & cài đặt AwareTime

## 0. Yêu cầu

* macOS + Xcode 15 hoặc mới hơn (Xcode 16 được dùng trên CI).
* iPhone thật chạy **iOS 16.0+** (Live Activity/Dynamic Island cần iOS 16.1+).
* Một Apple ID. Tài khoản miễn phí đủ để chạy thử qua Xcode; muốn IPA ad-hoc
  cài cho người khác thì cần Apple Developer Program.

> **Screen Time API không chạy trên Simulator.** `AuthorizationCenter` sẽ báo
> `unavailable`. Simulator vẫn dùng được để kiểm tra UI và chế độ mô phỏng.

---

## 1. Mở project

```bash
open AwareTime.xcodeproj
```

Project được sinh bởi `Tools/generate_xcodeproj.py` và đã commit, nên không cần
XcodeGen, CocoaPods hay SPM.

## 2. Đặt Team và bundle id

1. Trong Xcode chọn project `AwareTime` → **PROJECT → AwareTime → Build Settings**.
2. Tìm `BUNDLE_ID_PREFIX`, đổi `com.deocomate` thành prefix của bạn nếu cần.
   (Hoặc sửa hằng số cùng tên trong `Tools/generate_xcodeproj.py` rồi
   `make project` — cách này giữ project và script đồng bộ.)
3. Chọn lần lượt cả 6 target → tab **Signing & Capabilities** → **Team**.
   Bật *Automatically manage signing*.

Bundle id của các target:

```
com.<prefix>.awaretime                 (app)
com.<prefix>.awaretime.monitor         (DeviceActivityMonitor)
com.<prefix>.awaretime.shieldconfig    (ShieldConfiguration)
com.<prefix>.awaretime.shieldaction    (ShieldAction)
com.<prefix>.awaretime.report          (DeviceActivityReport)
com.<prefix>.awaretime.widget          (Live Activity + widget)
```

App Group dùng chung: `group.com.<prefix>.awaretime`

## 3. Capabilities cần thiết

Các file `.entitlements` trong repo đã khai báo sẵn:

| Target | Family Controls | App Groups | Time-Sensitive Notifications |
|---|---|---|---|
| AwareTime | ✅ | ✅ | ✅ |
| DeviceActivityMonitorExtension | ✅ | ✅ | ✅ |
| ShieldConfigurationExtension | ✅ | ✅ | — |
| ShieldActionExtension | ✅ | ✅ | — |
| DeviceActivityReportExtension | ✅ | ✅ | — |
| AwareTimeWidget | — | ✅ | — |

Với *Automatically manage signing*, Xcode tự tạo App ID và bật các capability
này trên Developer Portal. **Family Controls (Development)** dùng được cho mọi
tài khoản; bản **Distribution** (TestFlight/App Store) cần Apple phê duyệt qua
form [Family Controls Distribution Request](https://developer.apple.com/contact/request/family-controls-distribution).

Nếu Xcode báo *"Cannot create a provisioning profile"* cho Family Controls:
mở [developer.apple.com → Identifiers](https://developer.apple.com/account/resources/identifiers/list),
chọn App ID tương ứng và tick **Family Controls** thủ công.

## 4. Chạy trên thiết bị

Chọn scheme `AwareTime`, chọn iPhone của bạn, ⌘R.

Lần đầu mở app: cấp quyền Thông báo → cấp quyền Screen Time (iOS sẽ hỏi
"Allow AwareTime to access Screen Time?") → chọn ứng dụng cần theo dõi → đặt mốc.

---

## 5. Lấy file .ipa

### 5a. IPA chưa ký — tự động từ GitHub Actions

Mỗi push lên `main` hoặc `claude/**` sẽ chạy workflow **iOS Build**:

1. Vào tab **Actions** của repo → chọn run mới nhất.
2. Ở mục **Artifacts**, tải `awaretime-unsigned-ipa`.
3. Giải nén được `AwareTime-1.0.0-<run>-unsigned.ipa`.

IPA này chưa có chữ ký, nên **không cài trực tiếp được**. Ký lại bằng một
trong các cách sau:

* **Sideloadly** (macOS/Windows) — kéo IPA vào, đăng nhập Apple ID, Start.
* **AltStore / SideStore** — thêm IPA qua *My Apps → +*.
* **ios-app-signer** (macOS) — chọn IPA, chọn provisioning profile, Start.

> Quan trọng: công cụ ký lại phải dùng provisioning profile **có bật Family
> Controls**, nếu không app vẫn mở được nhưng phần Screen Time sẽ báo lỗi
> `unavailable`. Khi đó vẫn có thể dùng nút **Chạy thử nhanh** để kiểm tra
> thông báo, Live Activity và giao diện màn chắn.

Tạo tag `v*` (ví dụ `git tag v1.0.0 && git push --tags`) thì IPA còn được đính
kèm vào GitHub Release.

### 5b. IPA đã ký — cài trực tiếp

**Trên máy Mac:**

```bash
APPLE_TEAM_ID=XXXXXXXXXX make signed-ipa
# → build/export/AwareTime.ipa
```

Cài bằng Apple Configurator, Xcode → *Devices and Simulators → Installed Apps →
+*, hoặc Finder. Thiết bị phải nằm trong danh sách ad-hoc của team.

**Trên GitHub Actions:** thêm 4 repository secrets rồi chạy workflow
*iOS Build* bằng tay với tuỳ chọn **signed**:

| Secret | Nội dung |
|---|---|
| `APPSTORE_API_KEY_ID` | Key ID của App Store Connect API key |
| `APPSTORE_API_ISSUER_ID` | Issuer ID |
| `APPSTORE_API_PRIVATE_KEY` | Toàn bộ nội dung file `.p8` |
| `APPLE_TEAM_ID` | Team ID 10 ký tự |

Artifact `awaretime-signed-ipa` sẽ chứa IPA ad-hoc.

### 5c. IPA chưa ký — trên máy Mac của bạn

```bash
make ipa
# → build/ipa/AwareTime-1.0.0-unsigned.ipa
```

---

## 6. Xuất bản qua TestFlight

TestFlight yêu cầu entitlement **Family Controls (Distribution)**. Sau khi Apple
phê duyệt:

```bash
xcodebuild -project AwareTime.xcodeproj -scheme AwareTime \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/AwareTime.xcarchive -allowProvisioningUpdates archive
```

rồi Xcode → **Organizer → Distribute App → App Store Connect**.

Trong phần App Privacy, khai báo rằng app dùng Screen Time API và **không** thu
thập dữ liệu (AwareTime không có code mạng).

---

## 7. Xử lý sự cố

| Triệu chứng | Nguyên nhân thường gặp |
|---|---|
| `requestAuthorization` lỗi `unavailable` | Đang chạy Simulator, hoặc bản build thiếu entitlement Family Controls |
| `invalidAccountType` | Chưa đăng nhập iCloud, hoặc dùng tài khoản con trong Family Sharing mà chọn `.individual` |
| Thẻ **Thiếu App Group** trong onboarding | Entitlement App Groups chưa được ký vào bản build; kiểm tra Signing & Capabilities của cả 6 target |
| Không có sự kiện nào sau 15 phút | Chưa bật “Giám sát hằng ngày”, hoặc chưa chọn ứng dụng nào. Kiểm tra **Cài đặt → Thông tin kỹ thuật → Lịch đã cài** |
| Màn chắn không hiện | `shieldEnabled` đang tắt, hoặc đang trong thời gian gia hạn. Thử nút **Chặn ngay** |
| Live Activity không xuất hiện | Cần iOS 16.1+, và phải bật *Cài đặt → AwareTime → Hoạt động trực tiếp*. Live Activity chỉ khởi động được khi app đang mở |
| Widget trống | Widget đọc dữ liệu qua App Group; nếu App Group sai thì mọi giá trị bằng 0 |
| CI báo *"AwareTime.xcodeproj is stale"* | Chạy `make project` rồi commit lại |

Tab **Cài đặt → Thông tin kỹ thuật** trong app hiển thị App Group id, bundle id,
trạng thái quyền và trạng thái lịch giám sát — nên xem chỗ này trước tiên.
