//
//  ProfileView.swift
//  Follower
//
//  个人 Profile Tab — 由仪表盘右上角弹窗（AccountProfileSheet）迁移为独立页面。
//  内容：个人资料头部 + 活动状态 + 账号管理（连接/切换/删除）。
//  设置入口已移至 Dashboard 右上角（本页不重复）。
//  数据源复用 SettingsViewModel（accounts / selectedAccountId / deleteLocalData）。
//

import SwiftUI

/// 个人 Profile Tab — 个人资料 / 活动状态 / 账号管理
struct ProfileView: View {
    @Bindable var settingsViewModel: SettingsViewModel

    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    @State private var showAccountSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 主题渐变背景 — 与 Dashboard 同款观感
                LinearGradient(
                    colors: theme.backgroundGradientColors,
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                profileForm
                    .tint(theme.accentPrimary)   // 所有默认图标/Label 同步主题色
                    .navigationTitle(loc(L10n.Tab.profile))
                    .navigationBarTitleDisplayMode(.inline)
            }
            // 连接新账号 — 保持弹窗呈现（与迁移前一致）
            .sheet(isPresented: $showAccountSheet) {
                AccountView(viewModel: AccountViewModel(
                    accountRepo: appState.container.accountRepository,
                    syncEngine: appState.container.syncEngine,
                    apiClient: appState.container.apiClient,
                    tokenProvider: appState.container.tokenProvider
                ))
                // sheet presentation root：显式同步系统模式（sheet 不继承父层 colorScheme）
                .preferredColorScheme(theme.isDark ? .dark : .light)
            }
        }
        // 连接新账号后刷新账号列表（与 DashboardVM 的 accountCreated 监听一致）
        .onReceive(NotificationCenter.default.publisher(for: .accountCreated)) { _ in
            Task { await settingsViewModel.loadSettings() }
        }
        .task { await settingsViewModel.loadSettings() }
    }

    // MARK: - 个人资料 Form（与 SettingsView 同款卡片写法）

    private var profileForm: some View {
        Form {
            // 个人资料 — 头像 + 用户名 + 状态徽章
            Section { profileHeaderSection.listRowBackground(theme.cardSurface) }
                .listRowInsets(rowInsets)

            // 活动状态
            Section { statusSection.listRowBackground(theme.cardSurface) } header: {
                Text(loc(L10n.Settings.activityStatus)).foregroundColor(theme.textSecondary)
            }
                .listRowInsets(rowInsets)

            // 账号（与 SettingsView 原账号区块同款写法）
            Section {
                Button { showAccountSheet = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20))
                            .foregroundStyle(theme.accentPrimary)
                        Text(loc(L10n.Account.connectNew))
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 64)   // 统一卡片行高度
                }.listRowBackground(theme.cardSurface)
            } header: {
                Text(loc(L10n.Settings.accounts)).foregroundColor(theme.textSecondary)
            }
                .listRowInsets(rowInsets)

            Section { accountSection.listRowBackground(theme.cardSurface) }
                .listRowInsets(rowInsets)
        }
        .scrollContentBackground(.hidden)
        // Scroll Edge Effect — 内容与导航栏 / TabBar 玻璃控件间的柔和过渡
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    /// 统一行内边距 — 顶部/底部 0，左右 16（消除 Form 默认 padding 差异）
    private var rowInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
    }

    // MARK: - 个人资料

    /// 个人资料头部 — Liquid Glass 头像 + 用户名 + 平台 + 状态徽章
    private var profileHeaderSection: some View {
        HStack(spacing: 14) {
            // iOS 26 Liquid Glass 头像 — 纯 icon + Material 圆底 + 白色描边（与 Dashboard 一致）
            Image(systemName: "person.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(theme.accentPrimary)
                .frame(width: 44, height: 44)
                .background {
                    Circle().fill(.ultraThinMaterial)
                }
                .overlay {
                    Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("@\(selectedAccount?.username ?? "")")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Text(loc(L10n.Account.instagram))
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            // 账户状态徽章
            Text(selectedAccount?.authState.rawValue.capitalized ?? "—")
                .font(.caption)
                .foregroundColor(isAuthorized ? theme.positiveGreen : theme.negativeRed)
        }
        .frame(height: 64)   // 统一卡片行高度
    }

    // MARK: - 活动状态

    private var statusSection: some View {
        HStack {
            Label(loc(L10n.Settings.activityStatus), systemImage: "figure.run")
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text(authStateLabel)
                .font(.subheadline)
                .foregroundColor(isAuthorized ? theme.positiveGreen : theme.negativeRed)
        }
        .frame(height: 64)   // 统一卡片行高度
    }

    // MARK: - 账号（与设置页原账号区块同款）

    /// 账号列表 — 点击行切换当前选中账号（勾选标记），滑动删除
    private var accountSection: some View {
        Group {
            ForEach(settingsViewModel.accounts, id: \.id) { account in
                Button {
                    if let id = account.id {
                        settingsViewModel.selectedAccountId = id
                        // 同步全局选中账号 — Dashboard / Trends / Decisions 经 AppState 联动
                        appState.selectedAccountId = id
                    }
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(account.id == settingsViewModel.selectedAccountId ? theme.accentPrimary : theme.accentPrimary.opacity(0.6))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.username).font(.subheadline)
                            Text(loc(L10n.Account.instagram)).font(.caption).foregroundColor(theme.textSecondary)
                        }
                        Spacer()
                        if account.id == settingsViewModel.selectedAccountId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.accentPrimary)
                        }
                        Text(account.authState.rawValue.capitalized).font(.caption)
                            .foregroundColor(account.authState == .authorized ? theme.positiveGreen : theme.negativeRed)
                    }
                    .frame(height: 64)   // 统一卡片行高度
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    if let id = settingsViewModel.accounts[index].id {
                        Task { await settingsViewModel.deleteLocalData(accountId: id) }
                    }
                }
            }
            if settingsViewModel.accounts.isEmpty {
                Label(loc(L10n.Dashboard.connectAccount), systemImage: "person.crop.circle.badge.plus")
                    .foregroundColor(theme.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private var selectedAccount: Account? {
        settingsViewModel.accounts.first(where: { $0.id == settingsViewModel.selectedAccountId })
    }

    private var isAuthorized: Bool {
        selectedAccount?.authState == .authorized
    }

    private var authStateLabel: String {
        selectedAccount?.authState.rawValue.capitalized ?? "—"
    }
}
