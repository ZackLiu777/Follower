//
//  DecisionsView.swift
//  Follower
//
//  Growth Decision Engine 主视图 — 时间线方案。
//

import SwiftUI

/// Growth Decision Engine 主视图
struct DecisionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    let viewModel: DecisionsViewModel

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
                    DecisionsTimelineView(cards: viewModel.cards)
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

#Preview("DecisionsView — Timeline") {
    let appState = AppState(databaseManager: DatabaseManager.shared)
    let viewModel = DecisionsViewModel(
        snapshotRepo: appState.container.snapshotRepository,
        metricRepo: appState.container.metricRepository,
        accountRepo: appState.container.accountRepository
    )
    return DecisionsView(viewModel: viewModel).environment(appState)
}

