import FamilyControls
import SwiftUI

@main
struct AwareTimeApp: App {

    @StateObject private var viewModel = UsageViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
                .tint(.awareCalm)
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    viewModel.reconcileOnForeground()
                }
        }
    }
}
