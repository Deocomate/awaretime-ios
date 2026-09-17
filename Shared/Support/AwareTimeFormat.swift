import Foundation

/// Small formatting helpers shared by the app, the widget and the extensions.
enum AwareTimeFormat {

    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    static func dayAndClock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter.string(from: date)
    }

    /// `95` → `1 giờ 35 phút`
    static func minutes(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0 phút" }
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) phút" }
        if rest == 0 { return "\(hours) giờ" }
        return "\(hours) giờ \(rest) phút"
    }

    /// `3725` seconds → `1 giờ 2 phút`
    static func duration(_ interval: TimeInterval) -> String {
        minutes(Int(interval) / 60)
    }

    /// `620` seconds → `10:20`
    static func countdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
