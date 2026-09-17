import SwiftUI

struct RootView: View {

    @EnvironmentObject private var viewModel: UsageViewModel

    var body: some View {
        Group {
            if viewModel.onboardingCompleted {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut, value: viewModel.onboardingCompleted)
    }
}

struct MainTabView: View {

    @EnvironmentObject private var viewModel: UsageViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MainView()
                .tabItem { Label("Hôm nay", systemImage: "gauge.with.needle") }
                .tag(0)

            HistoryView()
                .tabItem { Label("Lịch sử", systemImage: "list.bullet.rectangle") }
                .tag(1)

            SettingsView()
                .tabItem { Label("Cài đặt", systemImage: "slider.horizontal.3") }
                .tag(2)
        }
        .tint(.awareCalm)
    }
}
