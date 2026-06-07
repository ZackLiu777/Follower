//
//  PremiumGate.swift
//  Follower
//
//  Premium 功能门控组件。
//  - 试用期间：显示完整功能 + "Trial" 标记
//  - 试用结束后：仍显示按钮，但点击展示升级提示
//  - 不阻塞基础功能
//

import SwiftUI

// MARK: - PremiumGateModifier

struct PremiumGateModifier: ViewModifier {
    let featureKey: PremiumFeatureKey
    @EnvironmentObject private var appState: AppState
    @State private var showUpgradePrompt: Bool = false

    /// 同步读取 Premium 解锁状态 — 解锁后立即反映，无异步延迟
    private var isEnabled: Bool {
        appState.premiumEnabledFlags[featureKey.rawValue] ?? false
    }

    func body(content: Content) -> some View {
        Button {
            if isEnabled {
                // Feature enabled — no action
            } else {
                showUpgradePrompt = true
            }
        } label: {
            content
                .overlay(alignment: .topTrailing) {
                    if !isEnabled {
                        premiumLockBadge
                    } else if appState.isTrialActive {
                        trialBadge
                    }
                }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradePromptView(featureKey: featureKey)
        }
    }

    private var premiumLockBadge: some View {
        Image(systemName: "lock.fill")
            .font(.caption2)
            .padding(4)
            .background(.ultraThinMaterial)
            .foregroundColor(.secondary)
            .clipShape(Circle())
            .padding(6)
    }

    private var trialBadge: some View {
        Text(loc(L10n.Premium.trialBadge))
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.orange)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .padding(4)
    }

}

// MARK: - PremiumBadge

/// Premium 功能标记（列表/卡片中使用）
struct PremiumBadge: View {
    var body: some View {
        Text("PREMIUM")
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                LinearGradient(
                    colors: [.orange, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

// MARK: - View Extension

extension View {
    /// 为 Premium 功能添加门控
    func premiumGate(feature: PremiumFeatureKey) -> some View {
        modifier(PremiumGateModifier(featureKey: feature))
    }
}

// MARK: - UpgradePromptView

/// 升级提示页，试用结束或点击锁定功能时弹出
struct UpgradePromptView: View {
    let featureKey: PremiumFeatureKey
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 40)

                Text(loc(L10n.Premium.premiumFeature))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(featureKey.displayName)
                    .font(.headline)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 12) {
                    premiumBenefit(loc(L10n.Premium.benefit1))
                    premiumBenefit(loc(L10n.Premium.benefit2))
                    premiumBenefit(loc(L10n.Premium.benefit3))
                    premiumBenefit(loc(L10n.Premium.benefit4))
                    premiumBenefit(loc(L10n.Premium.benefit5))
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    if appState.isTrialActive {
                        Text(loc(L10n.Premium.trialActive))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Text(loc(L10n.Premium.upgradeTo))
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [.orange, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)

                        Text(loc(L10n.Premium.comingSoon))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 30)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(loc(L10n.Premium.close)) { dismiss() }
                }
            }
        }
    }

    private func premiumBenefit(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    UpgradePromptView(featureKey: .trendPrediction)
        .environmentObject(AppState(databaseManager: DatabaseManager.shared))
}
