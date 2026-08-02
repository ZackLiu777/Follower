//
// AccountView.swift
// Follower
//
// 账号管理页面 — Instagram Token 连接 / 手动创建 / 撤销 / 删除。
//

import SwiftUI

struct AccountView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AccountViewModel

    @State private var accessToken: String = ""

    /// 单一状态源 — 统一从 AppState 读取主题（避免双状态源半刷新）
    private var currentTheme: Theme { appState.currentTheme.theme }

    var body: some View {
        ZStack {
            // 主题渐变背景
            LinearGradient(colors: appState.currentTheme.theme.backgroundGradientColors, startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            NavigationStack {
                Form {
                    // MARK: 已连接账号列表
                    if !viewModel.accounts.isEmpty {
                        Section {
                            ForEach(viewModel.accounts, id: \.id) { account in
                                accountRow(account)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    if let id = viewModel.accounts[index].id {
                                        Task { await viewModel.deleteAccount(id) }
                                    }
                                }
                            }
                            .listRowBackground(currentTheme.cardSurface)
                        } header: {
                            Text(loc(L10n.Account.connectedAccounts))
                        }
                    }

                    // MARK: 添加新账号
                    Section {
                        if viewModel.isAddingAccount {
                            addAccountForm
                        } else {
                            Button { viewModel.isAddingAccount = true } label: {
                                Label(loc(L10n.Account.connectNew), systemImage: "plus.circle.fill")
                            }
                        }
                    } header: {
                        Text(viewModel.isAddingAccount ? loc(L10n.Account.addAccount) : loc(L10n.Account.connectNew))
                    } footer: {
                        if let error = viewModel.errorMessage {
                            Text(error).foregroundColor(currentTheme.negativeRed).font(.caption)
                        } else {
                            Text(loc(L10n.Account.footerHint))
                        }
                    }
                    .listRowBackground(currentTheme.cardSurface)
                }
                .scrollContentBackground(.hidden)
                .navigationTitle(loc(L10n.Account.title))
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if viewModel.isAddingAccount {
                            Button(loc(L10n.Account.cancel)) {
                                viewModel.isAddingAccount = false
                                viewModel.username = ""
                                viewModel.displayName = ""
                                viewModel.addMode = .manual
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if viewModel.isAddingAccount {
                            if viewModel.addMode == .token {
                                Button {
                                    Task { await viewModel.connectWithToken(accessToken) }
                                } label: {
                                    if viewModel.isConnecting { ProgressView() }
                                    else { Text(loc(L10n.Account.connect)).fontWeight(.semibold) }
                                }
                                .disabled(accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isConnecting)
                            } else if viewModel.addMode == .oauth {
                                // OAuth button is inside the form
                                EmptyView()
                            } else {
                                Button {
                                    Task { await viewModel.addAccount() }
                                } label: {
                                    if viewModel.isLoading {
                                        ProgressView()
                                    } else {
                                        Text(loc(L10n.Account.connect)).fontWeight(.semibold)
                                    }
                                }
                                .disabled(viewModel.username.isEmpty || viewModel.displayName.isEmpty || viewModel.isLoading)
                            }
                        } else {
                            Button(loc(L10n.Common.done)) { dismiss() }
                        }
                    }
                }
            }
        }
        // sheet presentation root：显式同步 colorScheme（系统色随主题明暗）
        .environment(\.colorScheme, currentTheme.isDark ? .dark : .light)
        .task { await viewModel.loadAccounts() }
        .onChange(of: viewModel.shouldDismiss) { _, dismiss in
            if dismiss { self.dismiss() }
        }
    }

    // MARK: - Add Account Form
    private var addAccountForm: some View {
        Group {
            // 模式切换
            Picker("Mode", selection: $viewModel.addMode) {
                Text("OAuth").tag(AccountViewModel.AddMode.oauth)
                Text("Token").tag(AccountViewModel.AddMode.token)
                Text("Test").tag(AccountViewModel.AddMode.manual)
            }
            .pickerStyle(.segmented)

            if viewModel.addMode == .oauth {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Login with your Instagram account via Meta OAuth.")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("Client ID (App ID)", text: $viewModel.clientId)
                        .font(.caption).autocapitalization(.none)
                    SecureField("Client Secret", text: $viewModel.clientSecret)
                        .font(.caption)
                    TextField("Redirect URI", text: $viewModel.redirectURI)
                        .font(.caption).autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button {
                        Task {
                            await viewModel.connectWithInstagram(
                                clientId: viewModel.clientId,
                                clientSecret: viewModel.clientSecret,
                                redirectURI: viewModel.redirectURI
                            )
                        }
                    } label: {
                        HStack {
                            if viewModel.isConnecting { ProgressView() }
                            Text(viewModel.isConnecting ? "Connecting..." : "Login with Instagram")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(currentTheme.accentPrimary)
                    .disabled(viewModel.clientId.isEmpty || viewModel.clientSecret.isEmpty || viewModel.redirectURI.isEmpty || viewModel.isConnecting)
                }
            } else if viewModel.addMode == .token {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Paste your Instagram access token directly.")
                        .font(.caption).foregroundColor(.secondary)
                    SecureField("Access Token (IGAA...)", text: $accessToken)
                        .autocapitalization(.none)
                        .disableAutocorrection(true).font(.caption)
                }
            } else {
                Group {
                    TextField(loc(L10n.Account.username), text: $viewModel.username)
                        .textContentType(.username).autocapitalization(.none)
                    TextField(loc(L10n.Account.displayName), text: $viewModel.displayName)
                        .textContentType(.name)
                }
            }
        }
    }

    // MARK: - Account Row
    @ViewBuilder
    private func accountRow(_ account: Account) -> some View {
        HStack {
            Image(systemName: "camera.fill")
                .font(.title3).foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName).font(.subheadline).fontWeight(.medium)
                Text("@\(account.username)").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(loc(L10n.Account.instagram) + " · " + authDisplayName(account.authState))
                .font(.caption2).padding(.horizontal, 8).padding(.vertical, 4)
                .background(account.authState == .authorized ? currentTheme.positiveGreen.opacity(0.15) : currentTheme.negativeRed.opacity(0.15))
                .foregroundColor(account.authState == .authorized ? currentTheme.positiveGreen : currentTheme.negativeRed)
                .clipShape(Capsule())
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                if let id = account.id { Task { await viewModel.revokeAccount(id) } }
            } label: { Label(loc(L10n.Account.revoke), systemImage: "xmark.shield") }
        }
    }

    private func authDisplayName(_ state: AuthState) -> String {
        switch state {
        case .authorized: return loc(L10n.Account.authorized)
        case .expired: return loc(L10n.Account.expired)
        case .revoked: return loc(L10n.Account.revoked)
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
    static let aggregationService = AggregationService(eventRepo: eventRepo, snapshotRepo: snapshotRepo, metricRepo: metricRepo)
    static let ingestionService = IngestionService(eventRepo: eventRepo, aggregationService: aggregationService)
    static let apiClient = InstagramAPIClient()
    static let tokenProvider = TokenProvider()
    static let syncEngine = SyncEngine(
        eventRepo: eventRepo, accountRepo: accountRepo,
        ingestionService: ingestionService,
        apiClient: apiClient, tokenProvider: tokenProvider
    )
}
#endif
