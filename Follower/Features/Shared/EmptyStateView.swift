//
//  EmptyStateView.swift
//  Follower
//
//  空状态占位组件。
//  用于展示无数据、离线、未登录等状态。
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.bottom, 8)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let actionLabel = actionLabel, let action = action {
                Button(action: action) {
                    Text(actionLabel)
                        .fontWeight(.medium)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

#Preview {
    EmptyStateView(
        icon: "person.crop.circle.badge.exclamationmark",
        title: "No Account Connected",
        message: "Connect your Instagram or TikTok account to start tracking your data.",
        actionLabel: "Connect Account",
        action: {}
    )
}
