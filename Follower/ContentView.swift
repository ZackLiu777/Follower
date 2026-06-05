//
//  ContentView.swift
//  Follower
//
//  应用主入口。主题切换响应由 ContentViewInner 内部的 @EnvironmentObject 驱动。

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ContentViewInner(container: appState.container)
            .environmentObject(appState)
    }
}

// MARK: - ContentViewInner

private struct ContentViewInner: View {
    let container: DIContainer
    @EnvironmentObject private var appState: AppState

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
        .withTheme(appState.currentTheme.theme)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState(databaseManager: DatabaseManager.shared))
}
