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

    private var currentTheme: Theme { appState.currentTheme.theme }
    private var commentsEnabled: Bool {
        appState.premiumEnabledFlags[PremiumFeatureKey.commentManagement.rawValue] ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: 帖子图片（真实图片，无 URL/加载失败降级色块+图标）
                PostImageView(post: post, cornerRadius: 12)
                    .frame(height: 260)
                    .padding(.horizontal)

                // MARK: 互动数据卡片
                VStack(spacing: 12) {
                    detailRow(icon: "heart.fill", color: .pink, label: "Likes", value: post.formattedLikes)
                    detailRow(icon: "text.bubble.fill", color: .blue, label: "Comments", value: "\(post.comments)")
                    detailRow(icon: "eye.fill", color: .gray, label: "Reach", value: "N/A")
                    detailRow(icon: "bookmark.fill", color: .green, label: "Saves", value: "N/A")
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // MARK: 帖文与日期
                VStack(alignment: .leading, spacing: 4) {
                    Text("Caption").font(.headline)
                    Text(post.caption).font(.body)
                    Text(post.date.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // MARK: 评论管理入口（Premium）
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
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            .padding(.vertical)
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
    }

    /// 互动指标行 — icon + 标签 + 数值
    private func detailRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).frame(width: 24)
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
    }
}
