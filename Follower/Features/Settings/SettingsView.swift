//
//  SettingsView.swift
//  Follower
//
//  设置页。Beta: 全部文案本地化 + 语言切换入口。

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showAccountSheet: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section { trialSection } header: { Text(loc(L10n.Settings.trialStatus)) }

                Section { accountSection } header: { Text(loc(L10n.Settings.accounts)) }

                Section {
                    languageSection
                    themeSection
                    colorSchemeSection
                } header: { Text(loc(L10n.Settings.appearance)) }

                Section {
                    exportSection
                } header: { Text(loc(L10n.Settings.dataExport)) } footer: {
                    Text(loc(L10n.Settings.exportFooter))
                }

                Section { storageInfoSection } header: { Text(loc(L10n.Settings.storage)) }

                Section { privacySection } header: { Text(loc(L10n.Settings.privacy)) }

                Section { premiumFeaturesSection } header: { Text(loc(L10n.Settings.premiumFeatures)) }
            }
            .navigationTitle(loc(L10n.Settings.title))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await viewModel.unlockAllPremium() }
                    } label: {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.orange)
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

    private var trialSection: some View {
        HStack {
            Label(
                viewModel.isTrialActive ? loc(L10n.Settings.trialActive) : loc(L10n.Settings.trialEnded),
                systemImage: viewModel.isTrialActive ? "timer" : "timer.badge.exclamationmark"
            )
            Spacer()
            Text(viewModel.trialRemainingTime)
                .foregroundColor(.secondary).font(.subheadline)
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Group {
            ForEach(viewModel.accounts, id: \.id) { account in
                HStack {
                    Image(systemName: account.platform == .instagram ? "camera.fill" : "play.rectangle.fill")
                    VStack(alignment: .leading) {
                        Text(account.username).font(.subheadline)
                        Text(account.platform == .instagram ? loc(L10n.Account.instagram) : loc(L10n.Account.tiktok))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(account.authState.rawValue.capitalized)
                        .font(.caption)
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
                HStack {
                    Label(loc(L10n.Dashboard.connectAccount), systemImage: "person.crop.circle.badge.plus")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        Picker(loc(L10n.Settings.language), selection: Binding(
            get: { appState.currentLanguage },
            set: { appState.setLanguage($0) }
        )) {
            ForEach(AppLanguage.allCases, id: \.self) { lang in
                Text(lang.displayName).tag(lang)
            }
        }
    }

    // MARK: - Theme

    private var themeSection: some View {
        Picker(loc(L10n.Settings.theme), selection: Binding(
            get: { viewModel.currentTheme },
            set: { newTheme in
                viewModel.updateTheme(newTheme)
                appState.currentTheme = newTheme
            }
        )) {
            ForEach(AppTheme.allCases, id: \.self) { t in
                Text(t.displayName).tag(t)
            }
        }
        .pickerStyle(.menu)
    }

    // MARK: - Color Scheme

    private var colorSchemeSection: some View {
        Picker(loc(L10n.Settings.colorScheme), selection: Binding(
            get: { appState.colorScheme },
            set: { appState.colorScheme = $0 }
        )) {
            Text(loc(L10n.Settings.system)).tag(nil as ColorScheme?)
            Text(loc(L10n.Settings.light)).tag(ColorScheme?.some(.light))
            Text(loc(L10n.Settings.dark)).tag(ColorScheme?.some(.dark))
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Export

    private var exportSection: some View {
        Group {
            Picker(loc(L10n.Settings.format), selection: $viewModel.exportFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.displayName).tag(format)
                }
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
                ShareLink(item: url) {
                    Label(loc(L10n.Settings.shareExport), systemImage: "square.and.arrow.up.fill")
                }
            }
        }
    }

    // MARK: - Storage

    private var storageInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(loc(L10n.Settings.localOnly), systemImage: "lock.shield").font(.subheadline)
            Text(loc(L10n.Settings.storageDescription))
                .font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Group {
            Button { showPrivacyPolicy() } label: {
                Label(loc(L10n.Settings.privacyPolicy), systemImage: "hand.raised")
            }
            Button(role: .destructive) { viewModel.showDeleteConfirmation = true } label: {
                Label(loc(L10n.Settings.deleteAllData), systemImage: "trash")
            }
            .confirmationDialog(
                loc(L10n.Settings.deleteConfirmationTitle),
                isPresented: $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(loc(L10n.Common.delete), role: .destructive) {
                    if let id = viewModel.selectedAccountId {
                        Task { await viewModel.deleteLocalData(accountId: id) }
                    }
                }
                Button(loc(L10n.Common.cancel), role: .cancel) {}
            } message: {
                Text(loc(L10n.Settings.deleteConfirmationMessage))
            }
        }
    }

    // MARK: - Premium

    private var premiumFeaturesSection: some View {
        Group {
            // Feature list
            ForEach(viewModel.premiumFeatures, id: \.id) { feature in
                HStack {
                    Text(feature.key.displayName).font(.subheadline)
                    Spacer()
                    if feature.enabled {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                    } else {
                        Image(systemName: "lock.fill").foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func showPrivacyPolicy() {}
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(
        trialManager: PreviewMocks.trialManager,
        exportService: PreviewMocks.exportService,
        accountRepo: PreviewMocks.accountRepo,
        premiumFeatureRepo: PreviewMocks.premiumRepo
    ))
    .environmentObject(AppState(databaseManager: DatabaseManager.shared))
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
