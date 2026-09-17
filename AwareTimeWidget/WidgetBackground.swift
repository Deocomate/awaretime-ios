import SwiftUI
import WidgetKit

extension View {
    /// iOS 17 requires widgets to declare their background explicitly; on
    /// iOS 16 the modifier does not exist yet.
    @ViewBuilder
    func awareWidgetBackground<S: ShapeStyle>(_ style: S) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(style, for: .widget)
        } else {
            background(style)
        }
    }
}
