//
//  ContentView.swift
//  Follower
//
//  应用主入口。主题和语言切换即时响应。

import SwiftUI

/// 应用主入口 — 主题和语言切换即时响应（AppState 从父级 FollowerApp 注入）
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ContentViewInner(container: appState.container, appState: appState)
    }
}

// MARK: - ContentViewInner

/// 内部实现 — 创建 ViewModel 并组装 TabView
private struct ContentViewInner: View {
    let container: DIContainer
    let appState: AppState

    @State private var dashboardVM: DashboardViewModel
    @State private var trendsVM: TrendsViewModel
    @State private var decisionsVM: DecisionsViewModel
    @State private var settingsVM: SettingsViewModel

    init(container: DIContainer, appState: AppState) {
        self.appState = appState
        self.container = container
        _dashboardVM = State(wrappedValue: DashboardViewModel(
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
        _trendsVM = State(wrappedValue: TrendsViewModel(
            snapshotRepo: container.snapshotRepository,
            metricRepo: container.metricRepository,
            accountRepo: container.accountRepository
        ))
        _decisionsVM = State(wrappedValue: DecisionsViewModel(
            snapshotRepo: container.snapshotRepository,
            metricRepo: container.metricRepository,
            accountRepo: container.accountRepository
        ))
        _settingsVM = State(wrappedValue: SettingsViewModel(
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
            DecisionsView(viewModel: decisionsVM)
                .tabItem { Label(loc(L10n.Decisions.tabDecisions), systemImage: "sparkle.magnifyingglass") }
                .accessibilityIdentifier("tab_decisions")
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
        .environment(AppState(databaseManager: DatabaseManager.shared))
}
