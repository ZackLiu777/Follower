//
//  ContentView.swift
//  Follower
//
//  应用主入口 View。
//  通过 ContentViewInner 持有 ViewModel，避免 body 重算时重复创建。

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ContentViewInner(container: appState.container)
    }
}

// MARK: - ContentViewInner

/// 持有 ViewModel 实例，确保无论 body 被调用多少次，ViewModel 只创建一次。
private struct ContentViewInner: View {
    let container: DIContainer

    @StateObject private var dashboardVM: DashboardViewModel
    @StateObject private var trendsVM: TrendsViewModel
    @StateObject private var settingsVM: SettingsViewModel

    init(container: DIContainer) {
        self.container = container
        _dashboardVM = StateObject(wrappedValue: DashboardViewModel(
            snapshotRepo: container.snapshotRepository,
            accountRepo: container.accountRepository,
            syncEngine: container.syncEngine
        ))
        _trendsVM = StateObject(wrappedValue: TrendsViewModel(
            snapshotRepo: container.snapshotRepository,
            metricRepo: container.metricRepository,
            accountRepo: container.accountRepository
        ))
        _settingsVM = StateObject(wrappedValue: SettingsViewModel(
            trialManager: container.trialManager,
            exportService: container.exportService,
            accountRepo: container.accountRepository,
            premiumFeatureRepo: container.premiumFeatureRepository
        ))
    }

    var body: some View {
        TabView {
            DashboardView(viewModel: dashboardVM)
                .tabItem { Label(loc(L10n.Tab.dashboard), systemImage: "chart.bar.fill") }

            TrendsView(viewModel: trendsVM)
                .tabItem { Label(loc(L10n.Tab.trends), systemImage: "chart.line.uptrend.xy") }

            SettingsView(viewModel: settingsVM)
                .tabItem { Label(loc(L10n.Tab.settings), systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState(databaseManager: DatabaseManager.shared))
}
