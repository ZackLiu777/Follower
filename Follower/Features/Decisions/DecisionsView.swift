//
//  DecisionsView.swift
//  Follower
//
//  Growth Decision Engine 主视图 — 调度 5 套 UI 方案。
//  提供分段选择器在方案间切换（仅限 Demo），最终版本固定使用一套方案。

import SwiftUI

/// Growth Decision Engine 主视图
///
/// 负责：
/// - 在 5 套 UI 方案（A-E）之间调度切换
/// - 管理加载状态和刷新操作
/// - 提供分段选择器供方案对比（Demo 阶段）
///
/// 最终版本将移除此分段选择器，固定使用一套 UI 方案
struct DecisionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    let viewModel: DecisionsViewModel

    /// Demo 阶段：0=Stack, 1=Timeline, 2=Grid, 3=Carousel, 4=List
    @State private var selectedScheme: Int = 0

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 主题渐变背景
                LinearGradient(
                    colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 0) {
                    // 方案切换器（仅 Demo 阶段使用）
                    schemePicker

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .frame(maxWidth: .infinity)
                        Spacer()
                    } else if viewModel.cards.isEmpty {
                        Spacer()
                        Text(loc(L10n.Decisions.noDecisions))
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                    } else {
                        schemeView
                    }
                }
            }
            .navigationTitle(loc(L10n.Decisions.title))
            .toolbar { refreshToolbarItem }
        }
        .task { await viewModel.loadInitialAccount() }
    }

    // MARK: - Scheme Picker (Demo Only)

    /// Demo 阶段方案切换器，最终版本移除
    private var schemePicker: some View {
        Picker("Scheme", selection: $selectedScheme) {
            Text(loc(L10n.Decisions.stack)).tag(0)
            Text(loc(L10n.Decisions.timeline)).tag(1)
            Text(loc(L10n.Decisions.grid)).tag(2)
            Text(loc(L10n.Decisions.carousel)).tag(3)
            Text(loc(L10n.Decisions.list)).tag(4)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Scheme Dispatch

    /// 根据选中方案索引，返回对应的子视图
    @ViewBuilder
    private var schemeView: some View {
        switch selectedScheme {
        case 0: DecisionsStackView(cards: viewModel.cards)
        case 1: DecisionsTimelineView(cards: viewModel.cards)
        case 2: DecisionsGridView(cards: viewModel.cards)
        case 3: DecisionsCarouselView(cards: viewModel.cards)
        case 4: DecisionsListView(cards: viewModel.cards)
        default: DecisionsStackView(cards: viewModel.cards)
        }
    }

    // MARK: - Toolbar

    /// 右上角刷新按钮
    private var refreshToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                Task { await viewModel.refreshDecisions() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(theme.accentPrimary)
            }
        }
    }
}

// MARK: - Preview

#Preview("DecisionsView — Stack (Default)") {
    let appState = AppState(databaseManager: DatabaseManager.shared)
    let viewModel = DecisionsViewModel(
        snapshotRepo: appState.container.snapshotRepository,
        metricRepo: appState.container.metricRepository,
        accountRepo: appState.container.accountRepository
    )
    return DecisionsView(viewModel: viewModel)
        .environment(appState)
}
