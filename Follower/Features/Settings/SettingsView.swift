//
//  SettingsView.swift
//  Follower
//
//  设置页：试用状态、账号管理、主题切换、数据导出、隐私、存储说明。
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel

    @State private var showAccountSheet: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section { trialSection } header: { Text("Trial Status") }

                Section { accountSection } header: { Text("Accounts") }

                Section { themeSection } header: { Text("Appearance") }

                Section {
                    exportSection
                } header: {
                    Text("Data Export")
                } footer: {
                    Text("All exports are saved locally. Your data never leaves your device.")
                }

                Section { storageInfoSection } header: { Text("Storage") }

                Section { privacySection } header: { Text("Privacy") }

                Section { premiumFeaturesSection } header: { Text("Premium Features") }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showAccountSheet) {
                AccountView(viewModel: AccountViewModel(
                    accountRepo: appState.container.accountRepository,
                    syncEngine: appState.container.syncEngine
                ))
            }
        }
        .task {
            await viewModel.loadSettings()
        }
    }

    // MARK: - Trial Section

    private var trialSection: some View {
        HStack {
            Label(
                viewModel.isTrialActive ? "Trial Active" : "Trial Ended",
                systemImage: viewModel.isTrialActive ? "timer" : "timer.badge.exclamationmark"
            )
            Spacer()
            Text(viewModel.trialRemainingTime)
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Group {
            ForEach(viewModel.accounts, id: \.id) { account in
                HStack {
                    Image(systemName: account.platform == .instagram ? "camera.fill" : "play.rectangle.fill")
                    VStack(alignment: .leading) {
                        Text(account.username).font(.subheadline)
                        Text(account.platform.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
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

            Button { showAccountSheet = true } label: {
                Label("Connect Account", systemImage: "plus.circle")
            }
        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        Picker("Theme", selection: Binding(
            get: { viewModel.currentTheme },
            set: { newTheme in
                viewModel.updateTheme(newTheme)
                appState.currentTheme = newTheme
            }
        )) {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                Text(theme.displayName).tag(theme)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Export Section

    private var exportSection: some View {
        Group {
            Picker("Format", selection: $viewModel.exportFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.displayName).tag(format)
                }
            }

            Button {
                Task { await viewModel.exportData() }
            } label: {
                HStack {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                    Spacer()
                    if viewModel.isExporting { ProgressView() }
                }
            }
            .disabled(viewModel.selectedAccountId == nil || viewModel.isExporting)

            if let url = viewModel.exportURL {
                ShareLink(item: url) {
                    Label("Share Export File", systemImage: "square.and.arrow.up.fill")
                }
            }
        }
    }

    // MARK: - Storage Info

    private var storageInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Local Only", systemImage: "lock.shield").font(.subheadline)
            Text("All data is stored locally on your device using SQLite. Nothing is uploaded to the cloud.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Group {
            Button { showPrivacyPolicy() } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Button(role: .destructive) {
                viewModel.showDeleteConfirmation = true
            } label: {
                Label("Delete All Local Data", systemImage: "trash")
            }
            .confirmationDialog(
                "Delete All Data?",
                isPresented: $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let id = viewModel.selectedAccountId {
                        Task { await viewModel.deleteLocalData(accountId: id) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all locally stored data. This action cannot be undone.")
            }
        }
    }

    // MARK: - Premium Features

    private var premiumFeaturesSection: some View {
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

    private func showPrivacyPolicy() { /* Alpha 阶段占位 */ }
}

// MARK: - Preview

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
