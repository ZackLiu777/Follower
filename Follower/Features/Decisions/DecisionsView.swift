//
//  DecisionsView.swift
//  Follower
//
//  Growth Decision Engine 主视图 — 调度 5 套 UI 方案。
//  提供分段选择器在方案间切换（仅限 Demo），最终版本固定使用一套方案。

import SwiftUI

/// Growth Decision Engine 主视图
struct DecisionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    let viewModel: DecisionsViewModel

    /// Demo 阶段：0=Stack, 1=Timeline, 2=Grid, 3=Carousel, 4=List
    @State private var selectedScheme: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                switch appState.syncState {
                case .noAccount:
                    EmptyStateView(icon: "person.crop.circle.badge.exclamationmark",
                        title: loc(L10n.Decisions.noAccountTitle),
                        message: loc(L10n.Decisions.noAccountMessage),
                        actionLabel: nil, action: nil)
                case .dataReady:
                    VStack(spacing: 0) { schemePicker; schemeView }
                case .syncing:
                    ProgressView(loc(L10n.Common.loading)).frame(maxWidth: .infinity, minHeight: 300)
                case .readyToSync:
                    EmptyStateView(icon: "arrow.triangle.2.circlepath",
                        title: loc(L10n.Decisions.noDataTitle),
                        message: loc(L10n.Decisions.noDataMessage),
                        actionLabel: loc(L10n.Common.syncNow),
                        action: { Task { await viewModel.refreshDecisions() } })
                }
            }
            .navigationTitle(loc(L10n.Decisions.title))
            .toolbar { refreshToolbarItem }
        }
        .task { await viewModel.loadInitialAccount() }
        .onChange(of: appState.syncState) { _, new in
            if new == .dataReady { Task { await viewModel.refreshDecisions() } }
        }
    }

    // MARK: - Scheme Picker (Demo Only)

    private var schemePicker: some View {
        Picker("Scheme", selection: $selectedScheme) {
            Text(loc(L10n.Decisions.stack)).tag(0)
            Text(loc(L10n.Decisions.timeline)).tag(1)
            Text(loc(L10n.Decisions.grid)).tag(2)
            Text(loc(L10n.Decisions.carousel)).tag(3)
            Text(loc(L10n.Decisions.list)).tag(4)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 8)
    }

    // MARK: - Scheme Dispatch

    @ViewBuilder
    private var schemeView: some View {
        Group {
            switch selectedScheme {
            case 0: DecisionsStackView(cards: viewModel.cards)
            case 1: DecisionsTimelineView(cards: viewModel.cards)
            case 2: DecisionsGridView(cards: viewModel.cards)
            case 3: DecisionsCarouselView(cards: viewModel.cards)
            case 4: DecisionsListView(cards: viewModel.cards)
            default: DecisionsStackView(cards: viewModel.cards)
            }
        }
        .onAppear { print("[schemeView] appear — cards: \(viewModel.cards.count)") }
        .onDisappear { print("[schemeView] disappear") }
    }

    // MARK: - Toolbar

    private var refreshToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { Task { await viewModel.refreshDecisions() } } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(theme.accentPrimary)
            }
        }
    }
}

// MARK: - Preview

#Preview("DecisionsView — Stack") {
    let appState = AppState(databaseManager: DatabaseManager.shared)
    let viewModel = DecisionsViewModel(
        snapshotRepo: appState.container.snapshotRepository,
        metricRepo: appState.container.metricRepository,
        accountRepo: appState.container.accountRepository
    )
    return DecisionsView(viewModel: viewModel).environment(appState)
}
