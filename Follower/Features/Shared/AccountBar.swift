//
//  AccountBar.swift
//  Follower
//
//  仪表盘导航栏头像按钮 — 置于 toolbar trailing，与「仪表盘」标题同一水平线。
//  约束：toolbar 安全尺寸（32pt，不超 toolbar 高度，避免与 Dynamic Island 重叠）、
//  纯简单视图（无 Spacer / 无 Menu / 无 sheet / 无 padding / 无 offset）。
//  点击触发 onAvatarTap，个人资料弹窗由父级 DashboardView 呈现。
//

import SwiftUI

/// 导航栏头像按钮 — Liquid Glass 头像（32pt toolbar 安全尺寸），点击弹出个人资料弹窗
struct AccountBar: View {
    let onAvatarTap: () -> Void

    @Environment(AppState.self) private var appState

    /// 单一状态源 — 统一从 AppState 读取主题
    private var currentTheme: Theme { appState.currentTheme.theme }

    var body: some View {
        Button(action: onAvatarTap) {
            avatarView
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("account_avatar_button")
    }

    /// 头像图标 — 32×32（toolbar 标准图标尺寸），无 padding / offset
    private var avatarView: some View {
        ZStack {
            Image(systemName: "person.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(currentTheme.accentPrimary)
        }
        .frame(width: 32, height: 32)
    }
}
