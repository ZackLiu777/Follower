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
    @State private var selectedTab: Int = 0

    init(container: DIContainer, appState: AppState) {
        self.appState = appState
        self.container = container
        _dashboardVM = State(wrappedValue: DashboardViewModel(
            snapshotRepo: container.snapshotRepository,
            metricRepo: container.metricRepository,
            accountRepo: container.accountRepository,
            syncEngine: container.syncEngine,
            eventRepo: container.eventRepository,
            predictionService: container.predictionService,
            activityService: container.activityAnalysisService,
            retentionService: container.retentionAnalysisService,
            scoringService: container.scoringService,
            geoService: container.geoDistributionService,
            comparisonService: container.comparisonService,
            aiService: container.aiAnalysisService,
            authenticityService: container.authenticityService,
            campaignComparisonService: container.campaignComparisonService,
            engagementHeatmapService: container.engagementHeatmapService
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
        TabView(selection: $selectedTab) {
            DashboardView(viewModel: dashboardVM, settingsViewModel: settingsVM)
                .tabItem {
                    Label(loc(L10n.Tab.dashboard),
                        systemImage: selectedTab == 0 ? "square.grid.2x2.fill" : "square.grid.2x2")
                }
                .tag(0).accessibilityIdentifier("tab_dashboard")
            TrendsView(viewModel: trendsVM)
                .tabItem {
                    Label(loc(L10n.Tab.trends),
                        systemImage: selectedTab == 1 ? "chart.line.uptrend.xyaxis" : "chart.line.uptrend.xyaxis")
                }
                .tag(1).accessibilityIdentifier("tab_trends")
            DecisionsView(viewModel: decisionsVM)
                .tabItem {
                    Label(loc(L10n.Decisions.tabDecisions),
                        systemImage: selectedTab == 2 ? "sparkle.magnifyingglass" : "magnifyingglass")
                }
                .tag(2).accessibilityIdentifier("tab_decisions")
        }
        // 主题同步状态机：实时注入 theme + tint（含 themeChanged 通知强制重绘）
        .themeSynced()
        .toolbarBackground(.hidden, for: .tabBar)  // 隐藏 TabBar 背景，让渐变透出
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}

#Preview {
    ContentView()
        .environment(AppState(databaseManager: DatabaseManager.shared))
}
