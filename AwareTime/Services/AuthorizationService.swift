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
        let signature = String(describing: error)

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
            return """
            Không dùng được Screen Time API trên bản build này.
            Thường là do thiếu entitlement “Family Controls” hoặc đang chạy trên Simulator. Xem docs/BUILD.md.
            """
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
