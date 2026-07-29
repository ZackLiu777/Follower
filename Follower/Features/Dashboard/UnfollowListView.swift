//
//  UnfollowListView.swift
//  Follower
//
//  Lambda: Premium 详情 — 取关列表。

import SwiftUI

/// Premium 详情页：展示最近取关用户列表
struct UnfollowListView: View {
    @Environment(\.theme) private var theme

    /// 取关用户数据列表
    let followers: [UnfollowEntry]

    /// 取关用户列表：头像圆圈 + 用户名 + 取关日期
    var body: some View {
        ZStack {
            // Theme background gradient
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            List(followers) { f in
                HStack {
                    // 头像圆圈（首字母 + 背景色）
                    ZStack {
                        Circle().fill(Color.gray.opacity(0.3)).frame(width: 44, height: 44)
                        Text(String(f.displayName.prefix(1))).font(.headline).foregroundColor(.white)
                    }
                    // 用户名
                    VStack(alignment: .leading) {
                        Text(f.displayName).font(.subheadline).fontWeight(.medium)
                        Text("@\(f.username)").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    // 日期 + 取关标签
                    VStack(alignment: .trailing) {
                        Text(f.date.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.caption).foregroundColor(.secondary)
                        Text("Unfollowed").font(.caption2).foregroundColor(theme.negativeRed)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.whoUnfollowedYou))
        .navigationBarTitleDisplayMode(.inline)
    }
}
