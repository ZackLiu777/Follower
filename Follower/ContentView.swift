//
//  ContentView.swift
//  Follower
//
//  应用主入口。主题和语言切换即时响应。

import SwiftUI

/// 应用主入口 — 主题和语言切换即时响应
struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ContentViewInner(container: appState.container)
            .environmentObject(appState)
            // 语言切换 → 强制重建 view tree → 重新调用 loc()
            .id(appState.currentLanguage.rawValue)
    }
}

// MARK: - ContentViewInner

/// 内部实现 — 创建 ViewModel 并组装 TabView
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
            syncEngine: container.syncEngine,
            eventRepo: container.eventRepository,
            predictionService: container.predictionService,
            activityService: container.activityAnalysisService,
            retentionService: container.retentionAnalysisService,
            scoringService: container.scoringService,
            geoService: container.geoDistributionService,
            comparisonService: container.comparisonService,
            aiService: container.aiAnalysisService
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
                .tabItem { Label(loc(L10n.Tab.dashboard), systemImage: "square.grid.2x2.fill") }
                .accessibilityIdentifier("tab_dashboard")
            TrendsView(viewModel: trendsVM)
                .tabItem { Label(loc(L10n.Tab.trends), systemImage: "chart.xyaxis.line") }
                .accessibilityIdentifier("tab_trends")
            SettingsView(viewModel: settingsVM)
                .tabItem { Label(loc(L10n.Tab.my), systemImage: "person.fill") }
                .accessibilityIdentifier("tab_settings")
        }
        .tint(appState.currentTheme.theme.accentPrimary)
        .withTheme(appState.currentTheme.theme)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState(databaseManager: DatabaseManager.shared))
}
