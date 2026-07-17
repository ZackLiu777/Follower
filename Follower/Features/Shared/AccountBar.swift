//
//  AccountBar.swift
//  Follower
//
//  Shared: 多页面共用的账户选择栏 — 头像 + 用户名 + 多账户切换 Menu。
//  用于 Dashboard 和 Trends 页面顶部。
//

import SwiftUI

/// 账户选择栏 — 显示当前选中账户信息，多账户时提供切换菜单
struct AccountBar: View {
    let accounts: [Account]
    let selectedAccountId: Int64?
    let onSelect: (Int64) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            // 头像
            Circle()
                .fill(theme.accentPrimary.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.accentPrimary)
                }

            // 用户名 + 账户类型
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(selectedAccount?.username ?? "")")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                    Text(loc(L10n.Dashboard.accountType))
                        .font(.system(size: 12))
                }
                .foregroundColor(theme.textSecondary)
            }

            Spacer()

            // 多账户切换指示
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
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private var selectedAccount: Account? {
        accounts.first(where: { $0.id == selectedAccountId })
    }
}
