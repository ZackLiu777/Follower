//
//  AccountBar.swift
//  Follower
//
//  仪表盘固定顶栏：右上角 Liquid Glass 账号头像（始终显示，不随滚动消失）。
//  点击头像 → 弹出非全屏设置弹窗（直接呈现设置页内容，无中间层、无嵌套）。
//

import SwiftUI

/// 仪表盘顶栏 — 右上角 Liquid Glass 头像 + 多账户切换（仅多账户时显示）
struct AccountBar: View {
    let accounts: [Account]
    let selectedAccountId: Int64?
    let settingsViewModel: SettingsViewModel
    let onSelect: (Int64) -> Void

    @Environment(\.theme) private var theme
    @State private var showSettingsSheet = false

    var body: some View {
        HStack(spacing: 12) {
            // 多账户快速切换（仅 >1 个账号时显示）
            if accounts.count > 1 {
                Menu {
                    ForEach(accounts, id: \.id) { account in
                        Button {
                            if let id = account.id { onSelect(id) }
                        } label: {
                            HStack {
                                Text("@\(account.username)")
                                if account.id == selectedAccountId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }

            Spacer()

            // 右上角账号头像 — Liquid Glass + 点击弹出设置弹窗（直接呈现设置页）
            Button {
                showSettingsSheet = true
            } label: {
                avatarView
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("account_avatar_button")
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)   // 相比原布局上移
        .sheet(isPresented: $showSettingsSheet) {
            AccountProfileSheet(
                accounts: accounts,
                selectedAccountId: selectedAccountId,
                settingsViewModel: settingsViewModel,
                onSelect: onSelect
            )
        }
    }

    /// Liquid Glass 头像 — Material 毛玻璃 + theme.cardSurface 半透明色叠层
    private var avatarView: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            Circle().fill(theme.cardSurface)
            Circle().stroke(theme.divider, lineWidth: 0.5)
            Image(systemName: "person.fill")
                .font(.system(size: 18))
                .foregroundColor(theme.accentPrimary)
        }
        .frame(width: 44, height: 44)
        .shadow(color: .black.opacity(theme.isDark ? 0.10 : 0.05), radius: 6, y: 2)
    }
}
