//
//  ErrorBanner.swift
//  Follower
//
//  Beta: 统一错误提示横幅。由父 View 的 if 控制出现/消失，配合 transition 动画。

import SwiftUI

/// 统一错误横幅 — 红色半透明毛玻璃条，带重试和关闭按钮
struct ErrorBanner: View {
    let message: String
    let onDismiss: (() -> Void)?
    let onRetry: (() -> Void)?

    @Environment(\.theme) private var theme

    /// 水平布局：警告图标 + 错误消息 + 重试按钮 + 关闭按钮
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.textInverted)
            Text(message)
                .font(.subheadline)
                .foregroundColor(theme.textInverted)
            Spacer()
            if let onRetry {
                Button(action: onRetry) {
                    Text(loc(L10n.Common.retry))
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(theme.textInverted.opacity(0.25)).clipShape(Capsule())
                        .foregroundColor(theme.textInverted)
                }
            }
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.caption).foregroundColor(theme.textInverted.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(theme.negativeRed.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

/// 预览 — 带重试和关闭的错误横幅
#Preview {
    VStack {
        ErrorBanner(message: "Something went wrong", onDismiss: {}, onRetry: {})
        Spacer()
    }
    .padding(.top, 50)
}
