//
//  PostDetailView.swift
//  Follower
//
//  Lambda: 帖子详情页 — Mock 大图 + 互动数据。

import SwiftUI

/// 帖子详情页 — Mock 大图 + 互动数据（赞/评/曝光/收藏）
struct PostDetailView: View {
    let post: MediaPost

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: 图片占位
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: post.colorHex) ?? .gray)
                        .frame(height: 260)
                    VStack(spacing: 8) {
                        Image(systemName: post.typeIconName)
                            .font(.largeTitle).foregroundColor(.white)
                        Text("Mock Content").font(.caption).foregroundColor(.white.opacity(0.7))
                    }
                }
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
            }
            .padding(.vertical)
        }
        .navigationTitle("Post Detail")
        .navigationBarTitleDisplayMode(.inline)
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
