import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif

/// One source of truth for AwareTime's colours so the app, the widget and the
/// shield screen look like the same product.
enum BrandPalette {

    struct RGB {
        let red: Double
        let green: Double
        let blue: Double
    }

    static let ink = RGB(red: 0.07, green: 0.09, blue: 0.16)
    static let calm = RGB(red: 0.27, green: 0.53, blue: 0.96)
    static let mint = RGB(red: 0.18, green: 0.73, blue: 0.56)
    static let amber = RGB(red: 0.98, green: 0.68, blue: 0.16)
    static let alert = RGB(red: 0.92, green: 0.30, blue: 0.29)
    static let paper = RGB(red: 0.97, green: 0.97, blue: 0.99)

    static func rgb(for level: InterventionLevel) -> RGB {
        switch level {
        case .none: return mint
        case .notice: return calm
        case .warning: return amber
        case .shield: return alert
        }
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(brand: BrandPalette.RGB, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat(brand.red),
            green: CGFloat(brand.green),
            blue: CGFloat(brand.blue),
            alpha: alpha
        )
    }

    static let awareInk = UIColor(brand: BrandPalette.ink)
    static let awareCalm = UIColor(brand: BrandPalette.calm)
    static let awareMint = UIColor(brand: BrandPalette.mint)
    static let awareAmber = UIColor(brand: BrandPalette.amber)
    static let awareAlert = UIColor(brand: BrandPalette.alert)
    static let awarePaper = UIColor(brand: BrandPalette.paper)
}
#endif

#if canImport(SwiftUI)
extension Color {
    init(brand: BrandPalette.RGB, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: brand.red,
            green: brand.green,
            blue: brand.blue,
            opacity: opacity
        )
    }

    static let awareInk = Color(brand: BrandPalette.ink)
    static let awareCalm = Color(brand: BrandPalette.calm)
    static let awareMint = Color(brand: BrandPalette.mint)
    static let awareAmber = Color(brand: BrandPalette.amber)
    static let awareAlert = Color(brand: BrandPalette.alert)
    static let awarePaper = Color(brand: BrandPalette.paper)

    static func aware(for level: InterventionLevel) -> Color {
        Color(brand: BrandPalette.rgb(for: level))
    }
}
#endif
