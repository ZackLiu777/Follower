//
//  PostDetailView.swift
//  Follower
//
//  Lambda: 帖子详情页 — Mock 大图 + 互动数据。

import SwiftUI

/// 帖子详情页 — Mock 大图 + 互动数据（赞/评/曝光/收藏）
struct PostDetailView: View {
    let post: MediaPost

    @Environment(AppState.self) private var appState
    // 评论管理（Premium: commentManagement）
    @State private var showComments: Bool = false
    @State private var showUpgrade: Bool = false
    // 图片全屏查看器
    @State private var showViewer: Bool = false

    private var currentTheme: Theme { appState.currentTheme.theme }
    private var commentsEnabled: Bool {
        appState.premiumEnabledFlags[PremiumFeatureKey.commentManagement.rawValue] ?? false
    }

    var body: some View {
        ZStack {
            // v1.8：主题背景渐变（与 Dashboard 等页面一致）
            LinearGradient(
                colors: currentTheme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: 帖子图片 — 固定 4:5 容器 + Center Crop（点击全屏查看）
                    PostImageView(post: post, cornerRadius: 16, aspectRatio: 4.0 / 5.0)
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                        .onTapGesture { showViewer = true }

                    // MARK: 互动数据卡片（theme 化）
                    VStack(spacing: 12) {
                        detailRow(icon: "heart.fill", color: .pink, label: "Likes", value: post.formattedLikes)
                        detailRow(icon: "text.bubble.fill", color: .blue, label: "Comments", value: "\(post.comments)")
                        detailRow(icon: "eye.fill", color: .gray, label: "Reach", value: "N/A")
                        detailRow(icon: "bookmark.fill", color: .green, label: "Saves", value: "N/A")
                    }
                    .padding()
                    .background(currentTheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // MARK: 帖文与日期
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Caption")
                            .font(.headline)
                            .foregroundColor(currentTheme.textPrimary)
                        Text(post.caption)
                            .font(.body)
                            .foregroundColor(currentTheme.textSecondary)
                        Text(post.date.formatted(.dateTime.day().month(.abbreviated).year()))
                            .font(.caption)
                            .foregroundColor(currentTheme.textTertiary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(currentTheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // MARK: 评论管理入口（Premium）— 卡片 theme 化
                    Button {
                        if commentsEnabled {
                            showComments = true
                        } else {
                            showUpgrade = true
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .foregroundColor(currentTheme.accentPrimary)
                            Text("评论管理")
                                .font(.subheadline)
                                .foregroundColor(currentTheme.textPrimary)
                            Spacer()
                            if !commentsEnabled {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(currentTheme.textTertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(currentTheme.textTertiary)
                        }
                        .padding()
                        .background(currentTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Post Detail")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showComments) {
            CommentListView(
                accountId: appState.selectedAccountId,
                mediaID: post.igMediaID,
                commentService: appState.container.commentService
            )
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradePromptView(featureKey: .commentManagement)
                .presentationDetents([.fraction(0.75)])
                .preferredColorScheme(currentTheme.isDark ? .dark : .light)
        }
        .fullScreenCover(isPresented: $showViewer) {
            // 图片全屏查看器（相册式：看全 + 缩放平移），主题同步
            PostImageViewer(post: post)
                .preferredColorScheme(currentTheme.isDark ? .dark : .light)
        }
    }

    /// 互动指标行 — icon + 标签 + 数值（theme 色）
    private func detailRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).frame(width: 24)
            Text(label).foregroundColor(currentTheme.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(currentTheme.textPrimary)
        }
    }
}
