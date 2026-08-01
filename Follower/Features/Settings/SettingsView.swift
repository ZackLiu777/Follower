//
//  SettingsView.swift
//  Follower
//
//  设置页（完整内容）— 从个人资料弹窗的「设置」入口进入。
//  Form 多 Section：Trial / 账号 / 语言 / 主题 / 导出 / 存储 / 隐私 / Premium。
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.backgroundGradientColors, startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            Form {
                Section { trialSection.listRowBackground(theme.cardSurface) } header: { Text(loc(L10n.Settings.trialStatus)) }
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
            // 删除确认弹窗 — 挂在 Form 层级（附着在 Button 上 iOS 17+ 有 bug 不弹出）
            .confirmationDialog(loc(L10n.Settings.deleteConfirmationTitle), isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
                Button(loc(L10n.Common.delete), role: .destructive) {
                    Task { await viewModel.deleteAllAccounts() }
                }
                Button(loc(L10n.Common.cancel), role: .cancel) {}
            } message: { Text(loc(L10n.Settings.deleteConfirmationMessage)) }
        }
        .navigationTitle(loc(L10n.Settings.title))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadSettings() }
    }

    // MARK: - Trial
    private var trialSection: some View {
        HStack {
            Label(viewModel.isTrialActive ? loc(L10n.Settings.trialActive) : loc(L10n.Settings.trialEnded),
                  systemImage: viewModel.isTrialActive ? "timer" : "timer.circle")
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text(viewModel.trialRemainingTime).font(.subheadline).foregroundColor(.secondary)
        }
    }

    // MARK: - Language (free)
    private var languageRow: some View {
        HStack {
            Image(systemName: "globe")
                .foregroundColor(theme.accentPrimary)
            Text(loc(L10n.Settings.language)).font(.subheadline)
            Spacer()
            Picker("", selection: Binding(get: { appState.currentLanguage }, set: { appState.setLanguage($0) })) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in Text(lang.displayName).tag(lang) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
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
            Label(loc(L10n.Settings.localOnly), systemImage: "lock.shield.fill")
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
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
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Premium Master Toggle
    /// Master 开关 — ON 解锁全部，OFF 锁定全部（状态机聚合所有 key）
    private var premiumFeaturesSection: some View {
        Toggle(isOn: Binding(
            get: { viewModel.masterUnlocked },
            set: { newValue in Task { await viewModel.setMasterUnlocked(newValue) } }
        )) {
            Label(loc(L10n.Premium.unlockAll), systemImage: "crown.fill")
                .font(.subheadline)
                .foregroundColor(.orange)
        }
        .tint(theme.positiveGreen)
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
