//
//  ErrorBanner.swift
//  Follower
//
//  Beta: 统一错误提示横幅。带动画过渡。

import SwiftUI

struct ErrorBanner: View {
    let message: String
    let onDismiss: (() -> Void)?
    let onRetry: (() -> Void)?

    @State private var isVisible: Bool = false

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
                if let onRetry {
                    Button(action: onRetry) {
                        Text(loc(L10n.Common.retry))
                            .font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(.white.opacity(0.25)).clipShape(Capsule())
                    }
                }
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark").font(.caption).foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.red.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear { withAnimation(.spring(response: 0.4)) { isVisible = true } }
        }
    }
}

#Preview {
    VStack {
        ErrorBanner(message: "Something went wrong", onDismiss: {}, onRetry: {})
        Spacer()
    }
    .padding(.top, 50)
}
