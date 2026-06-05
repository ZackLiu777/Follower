//
//  DashboardView.swift
//  Follower
//
//  Dashboard 主页面。Beta: 全部文案本地化。

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil }, onRetry: { Task { await viewModel.loadAccounts() } })
                        .padding(.top, 8)
                }
                if viewModel.accounts.isEmpty {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.exclamationmark",
                        title: loc(L10n.Dashboard.noAccountTitle),
                        message: loc(L10n.Dashboard.noAccountMessage),
                        actionLabel: loc(L10n.Dashboard.connectAccount),
                        action: {}
                    )
                } else if let snapshot = viewModel.latestSnapshot {
                    contentView(snapshot: snapshot)
                } else if viewModel.isLoading {
                    ProgressView(loc(L10n.Common.loading))
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    EmptyStateView(
                        icon: "arrow.triangle.2.circlepath",
                        title: loc(L10n.Dashboard.noDataTitle),
                        message: loc(L10n.Dashboard.noDataMessage),
                        actionLabel: loc(L10n.Common.syncNow),
                        action: { Task { await viewModel.sync() } }
                    )
                }
            }
            .navigationTitle(loc(L10n.Dashboard.title))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isSyncing {
                        ProgressView()
                    } else {
                        Button { Task { await viewModel.sync() } } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .disabled(viewModel.selectedAccountId == nil)
                    }
                }
            }
            .refreshable { await viewModel.loadAccounts() }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.latestSnapshot?.id)
        .task { await viewModel.loadAccounts() }
    }

    @ViewBuilder
    private func contentView(snapshot: Snapshot) -> some View {
        VStack(spacing: 16) {
            accountPicker
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: loc(L10n.Dashboard.followers), value: snapshot.followersCount.formatted(.number), icon: "person.2.fill", tint: .blue)
                StatCard(title: loc(L10n.Dashboard.following), value: snapshot.followingCount.formatted(.number), icon: "person.fill.checkmark", tint: .green)
                StatCard(title: loc(L10n.Dashboard.media), value: snapshot.mediaCount.formatted(.number), icon: "photo.stack.fill", tint: .orange)
                StatCard(title: loc(L10n.Dashboard.engagementRate), value: String(format: "%.1f%%", snapshot.engagementRate * 100), icon: "heart.fill", tint: .pink)
                StatCard(title: loc(L10n.Dashboard.likes), value: snapshot.totalLikes.formatted(.number), icon: "hand.thumbsup.fill", tint: .red)
                StatCard(title: loc(L10n.Dashboard.comments), value: snapshot.totalComments.formatted(.number), icon: "text.bubble.fill", tint: .purple)
                StatCard(title: loc(L10n.Dashboard.shares), value: snapshot.totalShares.formatted(.number), icon: "arrowshape.turn.up.forward.fill", tint: .teal)
                StatCard(title: loc(L10n.Dashboard.views), value: snapshot.totalViews.formatted(.number), icon: "eye.fill", tint: .indigo)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private var accountPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.accounts, id: \.id) { account in
                    Button {
                        if let id = account.id { viewModel.selectAccount(id) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: account.platform == .instagram ? "camera.fill" : "play.rectangle.fill").font(.caption)
                            Text(account.username).font(.subheadline).fontWeight(.medium)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(viewModel.selectedAccountId == account.id ? AnyShapeStyle(.tint) : AnyShapeStyle(.regularMaterial))
                        .foregroundColor(viewModel.selectedAccountId == account.id ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    DashboardView(viewModel: DashboardViewModel(
        snapshotRepo: PreviewMocks.snapshotRepo,
        accountRepo: PreviewMocks.accountRepo,
        syncEngine: PreviewMocks.syncEngine
    )).environmentObject(AppState(databaseManager: DatabaseManager.shared))
}

#if DEBUG
private enum PreviewMocks {
    static let db = DatabaseManager.shared
    static let accountRepo = AccountRepository(db: db)
    static let eventRepo = EventRepository(db: db)
    static let snapshotRepo = SnapshotRepository(db: db)
    static let metricRepo = MetricRepository(db: db)
    static let aggregationService = AggregationService(eventRepo: eventRepo, snapshotRepo: snapshotRepo, metricRepo: metricRepo)
    static let ingestionService = IngestionService(eventRepo: eventRepo, aggregationService: aggregationService)
    static let syncEngine = SyncEngine(eventRepo: eventRepo, accountRepo: accountRepo, ingestionService: ingestionService)
}
#endif
