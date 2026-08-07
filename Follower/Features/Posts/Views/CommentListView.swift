//
//  CommentListView.swift
//  Follower
//
//  评论管理 — 帖子评论列表 + 回复 + 滑动删除。
//  仅对 BUSINESS / CREATOR 账号可用（Business API 端点）。
//

import SwiftUI

// MARK: - CommentListView

struct CommentListView: View {
    @Environment(AppState.self) private var appState
    let accountId: Int64?
    let mediaID: String

    @State private var viewModel: CommentViewModel

    init(accountId: Int64?, mediaID: String, commentService: CommentServiceProtocol) {
        self.accountId = accountId
        self.mediaID = mediaID
        _viewModel = State(initialValue: CommentViewModel(commentService: commentService))
    }

    private var currentTheme: Theme { appState.currentTheme.theme }

    var body: some View {
        VStack(spacing: 0) {
            // 评论列表
            List {
                if let error = viewModel.errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("无法加载评论", systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                                .foregroundColor(currentTheme.warningOrange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(currentTheme.textSecondary)
                            Button("重试") {
                                Task { await load() }
                            }
                            .font(.subheadline)
                            .foregroundColor(currentTheme.accentPrimary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if viewModel.comments.isEmpty && viewModel.errorMessage == nil {
                    Section {
                        ContentUnavailableView(
                            "暂无评论",
                            systemImage: "bubble.left",
                            description: Text("评论加载后显示在这里")
                        )
                    }
                }

                Section {
                    ForEach(viewModel.comments) { comment in
                        commentRow(comment)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .refreshable { await load() }
            .background(
                LinearGradient(
                    colors: currentTheme.backgroundGradientColors,
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )

            // 回复输入区
            HStack(spacing: 10) {
                TextField("回复评论…", text: $viewModel.replyText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(currentTheme.cardSurface.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    Task { await viewModel.reply(accountId: accountId ?? -1, mediaID: mediaID) }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(currentTheme.accentPrimary)
                        .frame(width: 36, height: 36)
                }
                .disabled(viewModel.replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("评论")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: - Row

    private func commentRow(_ comment: IGComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // 头像占位
            Circle()
                .fill(currentTheme.accentPrimary.opacity(0.25))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(currentTheme.accentPrimary)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(comment.username ?? "Instagram 用户")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(currentTheme.textSecondary)

                Text(comment.text ?? "")
                    .font(.subheadline)
                    .foregroundColor(currentTheme.textPrimary)

                if let timestamp = comment.timestamp {
                    Text(Self.formatTimestamp(timestamp))
                        .font(.caption2)
                        .foregroundColor(currentTheme.textTertiary)
                }
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing) {
            Button("删除", systemImage: "trash", role: .destructive) {
                Task { await viewModel.delete(accountId: accountId ?? -1, comment: comment) }
            }
        }
    }

    // MARK: - Private

    private func load() async {
        guard let accountId else {
            viewModel.errorMessage = "未选择账号，请先在仪表盘切换账号"
            return
        }
        await viewModel.load(accountId: accountId, mediaID: mediaID)
    }

    /// ISO8601 时间戳 → 可读时间
    private static func formatTimestamp(_ iso: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        fallback.locale = Locale(identifier: "en_US_POSIX")
        if let date = isoFormatter.date(from: iso) ?? fallback.date(from: iso) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return iso
    }
}
