import SwiftUI
import WidgetKit

@main
struct AwareTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        AwareTimeStatusWidget()
        AwareTimeLiveActivity()
    }
}
