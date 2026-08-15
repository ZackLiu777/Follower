//
//  PostListView.swift
//  Follower
//
//  Lambda: 完整帖子列表 — NavigationLink 进入 PostDetailView。
//  v1.9：移除发布助手/发布队列工具栏（内容排期功能已下线）。
//

import SwiftUI

/// 完整帖子列表 — NavigationLink 进入 PostDetailView
struct PostListView: View {
    let posts: [MediaPost]

    @Environment(AppState.self) private var appState

    private var currentTheme: Theme { appState.currentTheme.theme }

    var body: some View {
        List(posts) { post in
            NavigationLink { PostDetailView(post: post) } label: {
                PostRowView(post: post)
            }
            // v1.8：行卡片主题化 — theme.cardSurface 圆角卡片，跟随 9 套主题
            .listRowBackground(
                RoundedRectangle(cornerRadius: 12)
                    .fill(currentTheme.cardSurface)
                    .padding(.vertical, 3)
            )
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .navigationTitle("All Posts")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(
                colors: currentTheme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .scrollContentBackground(.hidden)
    }
}
