import FamilyControls
import Foundation
import UserNotifications

/// Wraps the two permissions AwareTime needs: Screen Time (Family Controls)
/// and notifications.
enum AuthorizationService {

    // MARK: - Family Controls

    static var screenTimeStatus: AuthorizationStatus {
        AuthorizationCenter.shared.authorizationStatus
    }

    static func requestScreenTime() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    static func revokeScreenTime() {
        AuthorizationCenter.shared.revokeAuthorization { _ in }
    }

    // MARK: - Notifications

    static func requestNotifications() async -> Bool {
        await NotificationScheduler.requestAuthorization()
    }

    static func notificationStatus() async -> UNAuthorizationStatus {
        await NotificationScheduler.authorizationStatus()
    }

    // MARK: - Error copy

    /// Turns the framework errors into something a user can act on.
    ///
    /// `FamilyControlsError` is matched on its textual form rather than on its
    /// cases, because the case list has changed between SDK releases and a
    /// friendly message is not worth a build break.
    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        let signature = String(describing: error)

        // "Không thể liên lạc với ứng dụng trợ giúp" / "Couldn't communicate
        // with a helper application": the XPC connection to the Screen Time
        // daemon was refused or dropped. NSXPCConnectionInterrupted (4097)
        // and NSXPCConnectionInvalid (4099) both surface this way.
        let isHelperFailure = (nsError.domain == NSCocoaErrorDomain && (nsError.code == 4097 || nsError.code == 4099))
            || signature.localizedCaseInsensitiveContains("helper application")
            || nsError.localizedDescription.localizedCaseInsensitiveContains("ứng dụng trợ giúp")
        if isHelperFailure {
            return helperConnectionAdvice()
        }

        if signature.contains("invalidAccountType") {
            return "Tài khoản iCloud không phù hợp. Hãy đăng nhập iCloud và bật Thời gian sử dụng trong Cài đặt."
        }
        if signature.contains("authorizationConflict") {
            return "Một ứng dụng quản lý khác đang giữ quyền Screen Time. Hãy tắt ứng dụng đó rồi thử lại."
        }
        if signature.contains("authorizationCanceled") {
            return "Bạn đã huỷ cấp quyền Screen Time."
        }
        if signature.contains("restricted") {
            return "Quyền Screen Time đang bị giới hạn trên thiết bị này."
        }
        if signature.contains("networkError") {
            return "Lỗi mạng khi xác thực quyền Screen Time. Thử lại khi có kết nối."
        }
        if signature.contains("unavailable") {
            return helperConnectionAdvice()
        }

        if error is FamilyControlsError {
            return """
            Không cấp được quyền Screen Time.
            \(error.localizedDescription)

            Hãy kiểm tra: đã đăng nhập iCloud, đã bật Thời gian sử dụng trong Cài đặt, và bản build có entitlement “Family Controls”. Xem docs/BUILD.md.
            """
        }

        return error.localizedDescription
    }

    /// Explains a failed XPC handshake by looking at what this build is
    /// actually entitled to, instead of repeating the opaque system message.
    static func helperConnectionAdvice() -> String {
        if ProvisioningProfileInspector.isSimulator {
            return """
            Không liên lạc được với tiến trình Screen Time của hệ thống.

            Nguyên nhân: đang chạy trên Simulator. Family Controls chỉ hoạt động trên iPhone/iPad thật.

            Hãy chạy trên thiết bị thật, hoặc dùng “Chạy thử nhanh” ở tab Hôm nay để kiểm tra giao diện và thông báo.
            """
        }

        switch ProvisioningProfileInspector.familyControlsState {
        case .missing:
            let name = ProvisioningProfileInspector.profile?.name ?? "không rõ"
            return """
            Không liên lạc được với tiến trình Screen Time của hệ thống.

            Nguyên nhân: bản build này KHÔNG có entitlement “com.apple.developer.family-controls”.
            Profile đang dùng: \(name)

            Cách sửa: bật Family Controls cho App ID tại developer.apple.com → Identifiers, tạo lại provisioning profile rồi ký lại app. Nếu bạn ký lại file IPA bằng Sideloadly/AltStore, công cụ đó phải dùng profile có quyền này. Xem docs/BUILD.md mục 7.
            """

        case .granted:
            return """
            Không liên lạc được với tiến trình Screen Time của hệ thống, dù bản build đã có entitlement Family Controls.

            Hãy thử theo thứ tự:
            1. Cài đặt → [tên bạn]: đã đăng nhập iCloud chưa.
            2. Cài đặt → Thời gian sử dụng: bật lên (không cần đặt mật mã).
            3. Nếu thiết bị nằm trong Family Sharing với vai trò trẻ em, quyền phải do phụ huynh cấp.
            4. Khởi động lại thiết bị — tiến trình Screen Time đôi khi cần khởi động lại.
            """

        case .indeterminate:
            return """
            Không liên lạc được với tiến trình Screen Time của hệ thống.

            Không đọc được provisioning profile của bản build này nên chưa xác định được có entitlement Family Controls hay không.

            Hãy kiểm tra: đã đăng nhập iCloud, đã bật Thời gian sử dụng trong Cài đặt, và app được ký bằng profile có bật Family Controls. Xem docs/BUILD.md mục 7.
            """
        }
    }
}

extension AuthorizationStatus {
    var vietnameseTitle: String {
        switch self {
        case .notDetermined: return "Chưa cấp quyền"
        case .denied: return "Đã bị từ chối"
        case .approved: return "Đã cấp quyền"
        @unknown default: return "Không rõ"
        }
    }

    var isApproved: Bool { self == .approved }
}
