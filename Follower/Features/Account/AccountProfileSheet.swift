//
//  AccountProfileSheet.swift
//  Follower
//
//  账号个人资料弹窗 — 从仪表盘右上角头像弹出。
//  卡片定义与 SettingsView 完全一致（Form + Section.listRowBackground(currentTheme.cardSurface)）。
//  账号管理唯一入口：个人资料 + 活动状态 + 账号 + 个性化入口（设置/集成）。
//

import SwiftUI

/// 账号个人资料弹窗 — 个人资料 / 活动状态 / 账号管理 / 个性化入口
struct AccountProfileSheet: View {
    let accounts: [Account]
    let selectedAccountId: Int64?
    let settingsViewModel: SettingsViewModel
    let onSelect: (Int64) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false
    @State private var showAccountSheet = false

    /// 单一状态源 — 统一从 AppState 读取主题（不再使用 @Environment(\.theme)，
    /// 避免双状态源导致切换主题半刷新）
    private var currentTheme: Theme { appState.currentTheme.theme }

    var body: some View {
        ZStack {
            // 主题渐变背景 — 从 AppState 确定性读取（不依赖环境传播）
            LinearGradient(colors: appState.currentTheme.theme.backgroundGradientColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            NavigationStack {
                profileForm
                    .tint(currentTheme.accentPrimary)   // 所有默认图标/Label 同步主题色
                    .navigationTitle(loc(L10n.Account.profileTitle))
                    .navigationBarTitleDisplayMode(.inline)
                    // sheet presentation root：显式同步 colorScheme（系统色随主题明暗）
                    .environment(\.colorScheme, currentTheme.isDark ? .dark : .light)
                    // 设置页 — 系统 push/pop 左右滑动动画
                    .navigationDestination(isPresented: $showSettings) {
                        SettingsView(viewModel: settingsViewModel)
                            .navigationBarBackButtonHidden(true)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button {
                                        showSettings = false   // pop 返回（自动滑动动画）
                                    } label: {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(currentTheme.textSecondary.opacity(0.45))
                                            .frame(width: 32, height: 32)
                                            .contentShape(Rectangle())
                                    }
                                    .accessibilityIdentifier("profile_back_button")
                                }
                            }
                    }
                    .toolbar {
                        // 透明关闭按钮 — 纯叉形图标，无填充无背景
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(currentTheme.textSecondary.opacity(0.45))
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityIdentifier("profile_close_button")
                        }
                    }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)   // 删除小横条
        .presentationCornerRadius(24)
        .sheet(isPresented: $showAccountSheet) {
            AccountView(viewModel: AccountViewModel(
                accountRepo: appState.container.accountRepository,
                syncEngine: appState.container.syncEngine,
                apiClient: appState.container.apiClient,
                tokenProvider: appState.container.tokenProvider
            ))
            // sheet presentation root：显式同步系统模式
            .preferredColorScheme(currentTheme.isDark ? .dark : .light)
        }
    }

    // MARK: - 个人资料 Form（与 SettingsView 同款卡片写法）

    private var profileForm: some View {
        Form {
            // 个人资料 — 头像 + 用户名 + 状态徽章
            Section { profileHeaderSection.listRowBackground(currentTheme.cardSurface) }
                .listRowInsets(rowInsets)

            // 活动状态
            Section { statusSection.listRowBackground(currentTheme.cardSurface) } header: {
                Text(loc(L10n.Settings.activityStatus)).foregroundColor(currentTheme.textSecondary)
            }
                .listRowInsets(rowInsets)

            // 账号（与 SettingsView 原账号区块同款写法）
            Section {
                Button { showAccountSheet = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20))
                            .foregroundStyle(currentTheme.accentPrimary)
                        Text(loc(L10n.Account.connectNew))
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 64)   // 统一卡片行高度
                }.listRowBackground(currentTheme.cardSurface)
            } header: {
                Text(loc(L10n.Settings.accounts)).foregroundColor(currentTheme.textSecondary)
            }
                .listRowInsets(rowInsets)

            Section { accountSection.listRowBackground(currentTheme.cardSurface) }
                .listRowInsets(rowInsets)

            // 个性化入口
            Section { personalizationSection.listRowBackground(currentTheme.cardSurface) } header: {
                Text(loc(L10n.Settings.personalization)).foregroundColor(currentTheme.textSecondary)
            }
                .listRowInsets(rowInsets)
        }
        .scrollContentBackground(.hidden)
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
                .foregroundStyle(currentTheme.accentPrimary)
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
                    .foregroundColor(currentTheme.textPrimary)
                Text(loc(L10n.Account.instagram))
                    .font(.system(size: 13))
                    .foregroundColor(currentTheme.textSecondary)
            }

            Spacer()

            // 账户状态徽章
            Text(selectedAccount?.authState.rawValue.capitalized ?? "—")
                .font(.caption)
                .foregroundColor(isAuthorized ? currentTheme.positiveGreen : currentTheme.negativeRed)
        }
        .frame(height: 64)   // 统一卡片行高度
    }

    // MARK: - 活动状态

    private var statusSection: some View {
        HStack {
            Label(loc(L10n.Settings.activityStatus), systemImage: "figure.run")
                .font(.subheadline)
                .foregroundColor(currentTheme.textPrimary)
            Spacer()
            Text(authStateLabel)
                .font(.subheadline)
                .foregroundColor(isAuthorized ? currentTheme.positiveGreen : currentTheme.negativeRed)
        }
        .frame(height: 64)   // 统一卡片行高度
    }

    // MARK: - 账号（与设置页原账号区块同款）

    /// 账号列表 — 点击行切换当前选中账号（勾选标记），滑动删除
    private var accountSection: some View {
        Group {
            ForEach(accounts, id: \.id) { account in
                Button {
                    if let id = account.id {
                        settingsViewModel.selectedAccountId = id
                        onSelect(id)
                    }
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(account.id == selectedAccountId ? currentTheme.accentPrimary : currentTheme.accentPrimary.opacity(0.6))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.username).font(.subheadline)
                            Text(loc(L10n.Account.instagram)).font(.caption).foregroundColor(currentTheme.textSecondary)
                        }
                        Spacer()
                        if account.id == selectedAccountId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(currentTheme.accentPrimary)
                        }
                        Text(account.authState.rawValue.capitalized).font(.caption)
                            .foregroundColor(account.authState == .authorized ? currentTheme.positiveGreen : currentTheme.negativeRed)
                    }
                    .frame(height: 64)   // 统一卡片行高度
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    if let id = accounts[index].id {
                        Task { await settingsViewModel.deleteLocalData(accountId: id) }
                    }
                }
            }
            if accounts.isEmpty {
                Label(loc(L10n.Dashboard.connectAccount), systemImage: "person.crop.circle.badge.plus")
                    .foregroundColor(currentTheme.textSecondary)
            }
        }
    }

    // MARK: - 个性化入口

    private var personalizationSection: some View {
        // 设置 ›（进入完整设置页 — 系统 push 滑动动画）
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(currentTheme.accentPrimary)
                Text(loc(L10n.Settings.title))
                    .font(.subheadline)
                    .foregroundColor(currentTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(currentTheme.textSecondary).font(.caption)
            }
            .frame(height: 64)   // 统一卡片行高度
        }
        .accessibilityIdentifier("profile_settings_link")
    }

    // MARK: - Helpers

    private var selectedAccount: Account? {
        accounts.first(where: { $0.id == selectedAccountId })
    }

    private var isAuthorized: Bool {
        selectedAccount?.authState == .authorized
    }

    private var authStateLabel: String {
        selectedAccount?.authState.rawValue.capitalized ?? "—"
    }
}
