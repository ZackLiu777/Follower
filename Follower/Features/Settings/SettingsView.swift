//
//  SettingsView.swift
//  Follower
//
//  Lambda-2: 移除颜色方案Picker（isDark 自动驱动）。减少卡片线条。
//

import SwiftUI

/// 设置页面 — 试用状态、账号管理、外观、导出、存储、隐私、Premium
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.theme) private var theme
    @State private var showAccountSheet: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                Form {
                Section { trialSection.listRowBackground(theme.cardSurface) } header: { Text(loc(L10n.Settings.trialStatus)) }
                Section { accountSection.listRowBackground(theme.cardSurface) } header: { Text(loc(L10n.Settings.accounts)) }
                Section {
                    languageSection.listRowBackground(theme.cardSurface)
                    themeSection.listRowBackground(theme.cardSurface)
                } header: { Text(loc(L10n.Settings.appearance)) }
                Section {
                    exportSection.listRowBackground(theme.cardSurface)
                } header: { Text(loc(L10n.Settings.dataExport)) } footer: { Text(loc(L10n.Settings.exportFooter)) }
                Section { storageInfoSection.listRowBackground(theme.cardSurface) } header: { Text(loc(L10n.Settings.storage)) }
                Section { privacySection.listRowBackground(theme.cardSurface) } header: { Text(loc(L10n.Settings.privacy)) }
                Section { premiumFeaturesSection.listRowBackground(theme.cardSurface) } header: { Text(loc(L10n.Settings.premiumFeatures)) }
            }
            .scrollContentBackground(.hidden)
            }
            .navigationTitle(loc(L10n.Settings.title))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { Task { await viewModel.unlockAllPremium() } } label: {
                        Image(systemName: "crown.fill").foregroundColor(.orange)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAccountSheet = true } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAccountSheet) {
                AccountView(viewModel: AccountViewModel(
                    accountRepo: appState.container.accountRepository,
                    syncEngine: appState.container.syncEngine
                ))
            }
        }
        .task { await viewModel.loadSettings() }
    }

    // MARK: - Trial

    /// 试用状态行 — 显示剩余时间
    private var trialSection: some View {
        HStack {
            Label(title: { Text(viewModel.isTrialActive ? loc(L10n.Settings.trialActive) : loc(L10n.Settings.trialEnded)) },
                  icon: { Image(systemName: viewModel.isTrialActive ? "timer" : "timer.circle") })
            Spacer()
            Text(viewModel.trialRemainingTime).foregroundColor(.secondary).font(.subheadline)
        }
    }

    // MARK: - Account

    /// 已连接账号列表 + 删除操作
    private var accountSection: some View {
        Group {
            ForEach(viewModel.accounts, id: \.id) { account in
                HStack {
                    Image(systemName: "camera.fill")
                    VStack(alignment: .leading) {
                        Text(account.username).font(.subheadline)
                        Text(loc(L10n.Account.instagram)).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(account.authState.rawValue.capitalized).font(.caption)
                        .foregroundColor(account.authState == .authorized ? .green : .red)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    if let id = viewModel.accounts[index].id {
                        Task { await viewModel.deleteLocalData(accountId: id) }
                    }
                }
            }
            if viewModel.accounts.isEmpty {
                Label(loc(L10n.Dashboard.connectAccount), systemImage: "person.crop.circle.badge.plus")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Language

    /// 应用语言选择 Picker
    private var languageSection: some View {
        Picker(loc(L10n.Settings.language), selection: Binding(get: { appState.currentLanguage }, set: { appState.setLanguage($0) })) {
            ForEach(AppLanguage.allCases, id: \.self) { lang in Text(lang.displayName).tag(lang) }
        }
    }

    // MARK: - Theme

    /// 主题风格选择 — Apple Native / Instagram
    private var themeSection: some View {
        Picker(loc(L10n.Settings.theme), selection: Binding(
            get: { viewModel.currentTheme },
            set: { viewModel.updateTheme($0); appState.currentTheme = $0 }
        )) {
            ForEach(AppTheme.allCases, id: \.self) { t in Text(t.displayName).tag(t) }
        }
        .pickerStyle(.menu)
    }

    // MARK: - Export

    /// 数据导出 — JSON / CSV 格式 + 分享
    private var exportSection: some View {
        Group {
            Picker(loc(L10n.Settings.format), selection: $viewModel.exportFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { f in Text(f.displayName).tag(f) }
            }
            Button { Task { await viewModel.exportData() } } label: {
                HStack {
                    Label(loc(L10n.Settings.exportData), systemImage: "square.and.arrow.up")
                    Spacer()
                    if viewModel.isExporting { ProgressView() }
                }
            }
            .disabled(viewModel.selectedAccountId == nil || viewModel.isExporting)
            if let url = viewModel.exportURL {
                ShareLink(item: url) { Label(loc(L10n.Settings.shareExport), systemImage: "square.and.arrow.up.fill") }
            }
        }
    }

    // MARK: - Storage

    /// 存储说明 — 本地优先 + 数据库描述
    private var storageInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(loc(L10n.Settings.localOnly), systemImage: "lock.shield").font(.subheadline)
            Text(loc(L10n.Settings.storageDescription)).font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: - Privacy

    /// 隐私 — 隐私政策 + 删除全部数据
    private var privacySection: some View {
        Group {
            Button { } label: { Label(loc(L10n.Settings.privacyPolicy), systemImage: "hand.raised") }
            Button(role: .destructive) { viewModel.showDeleteConfirmation = true } label: {
                Label(loc(L10n.Settings.deleteAllData), systemImage: "trash")
            }
            .confirmationDialog(loc(L10n.Settings.deleteConfirmationTitle), isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
                Button(loc(L10n.Common.delete), role: .destructive) {
                    if let id = viewModel.selectedAccountId { Task { await viewModel.deleteLocalData(accountId: id) } }
                }
                Button(loc(L10n.Common.cancel), role: .cancel) {}
            } message: { Text(loc(L10n.Settings.deleteConfirmationMessage)) }
        }
    }

    // MARK: - Premium

    /// Premium 功能开关列表 + 一键解锁
    private var premiumFeaturesSection: some View {
        Group {
            Button { Task { await viewModel.unlockAllPremium() } } label: {
                HStack {
                    Label(loc(L10n.Premium.unlockAll), systemImage: "crown.fill").foregroundColor(.orange)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                }
            }
            ForEach(viewModel.premiumFeatures, id: \.id) { feature in
                HStack {
                    Text(feature.key.displayName).font(.subheadline)
                    Spacer()
                    Image(systemName: feature.enabled ? "checkmark.seal.fill" : "lock.fill")
                        .foregroundColor(feature.enabled ? .green : .secondary)
                }
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(
        trialManager: PreviewMocks.trialManager, exportService: PreviewMocks.exportService,
        accountRepo: PreviewMocks.accountRepo, premiumFeatureRepo: PreviewMocks.premiumRepo
    )).environmentObject(AppState(databaseManager: DatabaseManager.shared))
}

#if DEBUG
private enum PreviewMocks {
    static let db = DatabaseManager.shared
    static let accountRepo = AccountRepository(db: db)
    static let eventRepo = EventRepository(db: db)
    static let snapshotRepo = SnapshotRepository(db: db)
    static let metricRepo = MetricRepository(db: db)
    static let premiumRepo = PremiumFeatureRepository(db: db)
    static let aggregationService = AggregationService(eventRepo: eventRepo, snapshotRepo: snapshotRepo, metricRepo: metricRepo)
    static let exportService = ExportService(snapshotRepo: snapshotRepo, metricRepo: metricRepo, eventRepo: eventRepo)
    static let trialManager = TrialManager(premiumFeatureRepo: premiumRepo)
}
#endif
