//
//  PublishActionSheet.swift
//  Follower
//
//  发布确认弹层 — 纯 SwiftUI 分享流程：
//  ShareLink 分享图片文件（Instagram 分享扩展），完成后用户确认结果。
//

import SwiftUI

// MARK: - PublishActionSheet

/// 发布动作弹层：图片预览 + 文案 + ShareLink + 结果确认
struct PublishActionSheet: View {
    let imageURL: URL
    let caption: String
    /// 完成回调：true = 已发布，false = 稍后再发
    let onComplete: (Bool) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var currentTheme: Theme { appState.currentTheme.theme }

    var body: some View {
        VStack(spacing: 16) {
            // 图片预览
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                default:
                    RoundedRectangle(cornerRadius: 16)
                        .fill(currentTheme.cardSurface)
                        .frame(height: 180)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(currentTheme.textTertiary)
                        }
                }
            }
            .padding(.top, 20)

            // 文案预览（已复制到剪贴板）
            if !caption.isEmpty {
                Text(caption)
                    .font(.subheadline)
                    .foregroundColor(currentTheme.textSecondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("文案已复制到剪贴板，分享后粘贴发布")
                .font(.caption)
                .foregroundColor(currentTheme.textTertiary)

            Spacer()

            // ShareLink — 系统分享面板（纯 SwiftUI）
            ShareLink(item: imageURL) {
                Label("分享到 Instagram", systemImage: "square.and.arrow.up")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [currentTheme.chartBarGradientStart, currentTheme.chartBarGradientEnd],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 结果确认
            HStack(spacing: 12) {
                Button("稍后再发") {
                    onComplete(false)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(currentTheme.cardSurface)
                .foregroundColor(currentTheme.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("已完成发布") {
                    onComplete(true)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(currentTheme.accentPrimary)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
        .background(currentTheme.backgroundGradientStart)
        .environment(\.colorScheme, currentTheme.isDark ? .dark : .light)
    }
}
