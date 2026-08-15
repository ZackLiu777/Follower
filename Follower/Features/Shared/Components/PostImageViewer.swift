//
//  PostImageViewer.swift
//  Follower
//
//  帖子图片全屏查看器（相册式）：
//  - 完整显示原图（scaledToFit，可看全）
//  - 捏合放大（1x–4x）+ 放大后拖动平移
//  - 单击关闭（未放大时）/ 双击还原（放大时）
//  - 背景与按钮全部走 theme（跟随 App 主题切换）
//

import SwiftUI

/// 全屏图片查看器 — 点击图片后呈现，fullScreenCover + themeSynced 使用
struct PostImageViewer: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    let post: MediaPost

    // 缩放 / 平移状态
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    /// 缩放范围
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    var body: some View {
        ZStack {
            // 主题背景（渐变 + 底层色叠层，深色模式自动适配）
            theme.backgroundPrimary.ignoresSafeArea()
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // 图片（完整显示，可缩放平移）
            imageContent
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnifyGesture)
                .gesture(dragGesture)
                .onTapGesture(count: 2) {
                    resetZoom()   // 双击还原
                }
                .onTapGesture {
                    if scale <= 1.0 { dismiss() }   // 未放大时单击关闭
                }

            // 关闭按钮（始终可点）
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(16)
                }
                Spacer()
            }
        }
        .themeSynced()   // 全屏卡片跟随 App 主题（sheet 环境快照防护）
    }

    // MARK: - 图片内容

    /// 完整显示图片（scaledToFit 看全），无 URL / 加载失败 → 占位
    private var imageContent: some View {
        Group {
            if let urlString = post.mediaURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .empty:
                        ProgressView().tint(theme.accentPrimary)
                    case .failure:
                        fallbackView
                    @unknown default:
                        fallbackView
                    }
                }
            } else {
                fallbackView
            }
        }
        .padding(24)
    }

    /// 占位（无图 / 加载失败）
    private var fallbackView: some View {
        VStack(spacing: 12) {
            Image(systemName: post.typeIconName)
                .font(.system(size: 44))
                .foregroundStyle(theme.textTertiary)
            Text(post.caption)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - 手势

    /// 捏合缩放：scale = lastScale × magnification，clamp 1...4
    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                clampOffset()   // 缩放变化后平移边界收敛
            }
    }

    /// 拖动平移：仅放大时有效
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard scale > 1.0 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
                clampOffset()
            }
    }

    /// 平移边界：放大后的图片边缘不能拖出屏幕中心区域
    private func clampOffset() {
        let maxOffset = max(0, (scale - 1) * 200)   // 简单边界：随缩放增大可平移范围
        offset.width = min(max(offset.width, -maxOffset), maxOffset)
        offset.height = min(max(offset.height, -maxOffset), maxOffset)
        lastOffset = offset
    }

    /// 双击还原
    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
}

// MARK: - Preview

#Preview("PostImageViewer") {
    PostImageViewer(post: MediaPost(
        id: 1, accountId: 1, igMediaID: "1", type: .image,
        date: Date(), likes: 10, comments: 2,
        caption: "测试图片查看器", mediaURL: nil, permalink: nil
    ))
}
