//
//  PostListView.swift
//  Follower
//
//  Lambda: 完整帖子列表 — 顶部工具栏提供发布助手与发布队列入口。
//

import SwiftUI

/// 完整帖子列表 — NavigationLink 进入 PostDetailView
struct PostListView: View {
    let posts: [MediaPost]

    @Environment(AppState.self) private var appState

    // 发布助手（Premium: contentScheduling）
    @State private var showComposer: Bool = false
    @State private var showUpgrade: Bool = false

    private var currentTheme: Theme { appState.currentTheme.theme }
    private var schedulingEnabled: Bool {
        appState.premiumEnabledFlags[PremiumFeatureKey.contentScheduling.rawValue] ?? false
    }

    var body: some View {
        List(posts) { post in
            NavigationLink { PostDetailView(post: post) } label: {
                PostRowView(post: post)
            }
        }
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    // 发布队列
                    NavigationLink {
                        PostQueueView(
                            draftRepo: appState.container.draftPostRepository,
                            assistant: appState.container.postAssistantService
                        )
                    } label: {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .foregroundColor(currentTheme.accentPrimary)
                    }

                    // 发布助手（Premium 门控）
                    Button {
                        if schedulingEnabled {
                            showComposer = true
                        } else {
                            showUpgrade = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(currentTheme.accentPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showComposer) {
            PostComposerView(
                draftRepo: appState.container.draftPostRepository,
                assistant: appState.container.postAssistantService
            )
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradePromptView(featureKey: .contentScheduling)
                .presentationDetents([.fraction(0.75)])
                .preferredColorScheme(currentTheme.isDark ? .dark : .light)
        }
    }
}
