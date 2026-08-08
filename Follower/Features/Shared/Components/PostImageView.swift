//
//  PostImageView.swift
//  Follower
//
//  帖子图片视图 — AsyncImage + 色块占位降级：
//  有 mediaURL 时加载 IG CDN 图片；无 URL / 加载失败 / 加载中时显示类型色块 + 图标。
//  列表缩略图（PostRowView）与详情大图（PostDetailView）共用。
//

import SwiftUI

/// 帖子图片：AsyncImage 加载 + phase 降级（色块+类型图标）
/// 尺寸由调用方 frame 决定，本组件只负责内容与裁切
struct PostImageView: View {
    /// 帖子数据（mediaURL 为图片地址，colorHex 为占位底色）
    let post: MediaPost
    /// 圆角（列表缩略图 8，详情大图 12）
    var cornerRadius: CGFloat = 12

    var body: some View {
        ZStack {
            // 占位底色：始终在最底层，loading/failure 时透出
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(hex: post.colorHex) ?? .gray)

            if let urlString = post.mediaURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .failure:
                        fallbackContent
                    @unknown default:
                        fallbackContent
                    }
                }
            } else {
                fallbackContent
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// 无图 / 加载失败时的降级内容：类型图标 + 弱提示
    private var fallbackContent: some View {
        VStack(spacing: 6) {
            Image(systemName: post.typeIconName)
                .font(.title3)
                .foregroundColor(.white)
            if post.mediaURL != nil {
                Text("加载失败")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}
