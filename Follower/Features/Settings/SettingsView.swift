//
//  SettingsView.swift
//  Follower
//
//  设置页面 — Premium 锁定主题/导出 + 所有行 SF Symbols。
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.theme) private var theme
    @State private var showAccountSheet: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                Form {
                    Section { trialSection.listRowBackground(theme.cardSurface) } header: { Text(loc(L10n.Settings.trialStatus)) }
                    Section {
                        Button { showAccountSheet = true } label: {
                            Label(loc(L10n.Account.connectNew), systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                        }.listRowBackground(theme.cardSurface)
                    } header: { Text(loc(L10n.Settings.accounts)) }
                    Section { accountSection.listRowBackground(theme.cardSurface) }
                    // 外观（主题切换 = Premium）
                    Section {
                        languageRow.listRowBackground(theme.cardSurface)
                        themeRow.listRowBackground(theme.cardSurface)
                    } header: { Text(loc(L10n.Settings.appearance)) }
                    // 数据导出（= Premium）
                    Section {
                        exportRow.listRowBackground(theme.cardSurface)
                    } header: { Text(loc(L10n.Settings.dataExport)) } footer: { Text(loc(L10n.Settings.exportFooter)) }
                    Section { storageInfoSection.listRowBackground(theme.cardSurface) } header: { Text(loc(L10n.Settings.storage)) }
                    Section { privacySection.listRowBackground(theme.cardSurface) } header: { Text(loc(L10n.Settings.privacy)) }
                    Section { premiumFeaturesSection.listRowBackground(theme.cardSurface) } header: { Text(loc(L10n.Settings.premiumFeatures)) }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(loc(L10n.Settings.title))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAccountSheet) {
                AccountView(viewModel: AccountViewModel(
                    accountRepo: appState.container.accountRepository,
                    syncEngine: appState.container.syncEngine,
                    apiClient: appState.container.apiClient,
                    tokenProvider: appState.container.tokenProvider
                ))
            }
        }
        .task { await viewModel.loadSettings() }
    }

    // MARK: - Trial
    private var trialSection: some View {
        HStack {
            Label(viewModel.isTrialActive ? loc(L10n.Settings.trialActive) : loc(L10n.Settings.trialEnded),
                  systemImage: viewModel.isTrialActive ? "timer" : "timer.circle")
            Spacer()
            Text(viewModel.trialRemainingTime).foregroundColor(.secondary).font(.subheadline)
        }
    }

    // MARK: - Account
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

    // MARK: - Language (free)
    private var languageRow: some View {
        Picker(loc(L10n.Settings.language), selection: Binding(get: { appState.currentLanguage }, set: { appState.setLanguage($0) })) {
            ForEach(AppLanguage.allCases, id: \.self) { lang in Text(lang.displayName).tag(lang) }
        }
    }

    // MARK: - Theme (Premium)
    private var themeRow: some View {
        HStack {
            Image(systemName: "paintpalette.fill")
                .foregroundColor(theme.accentPrimary)
            Text(loc(L10n.Settings.theme)).font(.subheadline)
            Spacer()
            if appState.premiumEnabledFlags[PremiumFeatureKey.themeSwitching.rawValue] == true {
                Picker("", selection: Binding(get: { viewModel.currentTheme }, set: { viewModel.updateTheme($0); appState.currentTheme = $0 })) {
                    ForEach(AppTheme.allCases, id: \.self) { t in Text(t.displayName).tag(t) }
                }.pickerStyle(.menu).labelsHidden()
            } else {
                Image(systemName: "lock.fill").foregroundColor(.secondary).font(.caption)
                Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
            }
        }
    }

    // MARK: - Export (Premium: csvExport key)
    private var exportRow: some View {
        Group {
            HStack {
                Image(systemName: "doc.text.fill").foregroundColor(theme.accentPrimary)
                Text(loc(L10n.Settings.format)).font(.subheadline)
                Spacer()
                if appState.premiumEnabledFlags[PremiumFeatureKey.csvExport.rawValue] == true {
                    Picker("", selection: $viewModel.exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { f in Text(f.displayName).tag(f) }
                    }.pickerStyle(.menu).labelsHidden()
                } else {
                    Image(systemName: "lock.fill").foregroundColor(.secondary).font(.caption)
                }
            }
            HStack {
                Image(systemName: "square.and.arrow.up.fill").foregroundColor(theme.accentPrimary)
                Text(loc(L10n.Settings.exportData)).font(.subheadline)
                Spacer()
                if appState.premiumEnabledFlags[PremiumFeatureKey.csvExport.rawValue] == true {
                    Button { Task { await viewModel.exportData() } } label: { Text(loc(L10n.Settings.exportData)) }
                        .disabled(viewModel.selectedAccountId == nil || viewModel.isExporting)
                } else {
                    Image(systemName: "lock.fill").foregroundColor(.secondary).font(.caption)
                }
            }
            if let url = viewModel.exportURL {
                ShareLink(item: url) {
                    Label(loc(L10n.Settings.shareExport), systemImage: "square.and.arrow.up.fill")
                }
            }
        }
    }

    // MARK: - Storage
    private var storageInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(loc(L10n.Settings.localOnly), systemImage: "lock.shield.fill").font(.subheadline)
            Text(loc(L10n.Settings.storageDescription)).font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: - Privacy
    private var privacySection: some View {
        Group {
            HStack {
                Image(systemName: "hand.raised.fill").foregroundColor(theme.accentPrimary)
                Text(loc(L10n.Settings.privacyPolicy)).font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
            }
            Button(role: .destructive) {
                viewModel.showDeleteConfirmation = true
            } label: {
                Label(loc(L10n.Settings.deleteAllData), systemImage: "trash.fill")
            }
            .confirmationDialog(loc(L10n.Settings.deleteConfirmationTitle), isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
                Button(loc(L10n.Common.delete), role: .destructive) {
                    if let id = viewModel.selectedAccountId { Task { await viewModel.deleteLocalData(accountId: id) } }
                }
                Button(loc(L10n.Common.cancel), role: .cancel) {}
            } message: { Text(loc(L10n.Settings.deleteConfirmationMessage)) }
        }
    }

    // MARK: - Premium Features
    private var premiumFeaturesSection: some View {
        Group {
            Button { Task { await viewModel.unlockAllPremium() } } label: {
                HStack {
                    Label(loc(L10n.Premium.unlockAll), systemImage: "crown.fill").foregroundColor(.orange)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
                }
            }
            ForEach(viewModel.premiumFeatures, id: \.id) { feature in
                HStack {
                    Image(systemName: premiumIcon(for: feature.key))
                        .foregroundColor(feature.enabled ? theme.positiveGreen : theme.textSecondary)
                        .frame(width: 24)
                    Text(feature.key.displayName).font(.subheadline)
                    Spacer()
                    Image(systemName: feature.enabled ? "checkmark.seal.fill" : "lock.fill")
                        .foregroundColor(feature.enabled ? theme.positiveGreen : theme.textSecondary)
                }
            }
        }
    }

    private func premiumIcon(for key: PremiumFeatureKey) -> String {
        switch key {
        case .trendPrediction, .followerGrowthPrediction: return "chart.line.uptrend.xyaxis"
        case .activityAnalysis: return "bolt.fill"
        case .retentionAnalysis, .churnAnalysis: return "person.2.fill"
        case .geoDistribution: return "globe.asia.australia.fill"
        case .engagementQualityScore: return "star.fill"
        case .longTermTrendComparison: return "arrow.left.arrow.right"
        case .csvExport, .excelExport: return "doc.text.fill"
        case .localAIAnalysis: return "brain.head.profile"
        case .advancedEncryption: return "lock.shield.fill"
        case .multiDeviceSync: return "icloud.fill"
        case .competitorComparison: return "chart.bar.fill"
        case .authenticityAssessment: return "checkmark.shield.fill"
        case .mediaKitExport: return "doc.richtext.fill"
        case .campaignTracking: return "flag.fill"
        case .engagementHeatmap: return "calendar.badge.clock"
        case .contentScheduling: return "clock.fill"
        case .commentManagement: return "bubble.left.and.bubble.right.fill"
        case .growthDecisions: return "sparkle.magnifyingglass"
        case .themeSwitching: return "paintpalette.fill"
        }
    }
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
