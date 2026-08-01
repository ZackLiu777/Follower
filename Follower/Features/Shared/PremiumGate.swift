//
//  PremiumGate.swift
//  Follower
//
//  Premium 功能门控组件。
//  - Dashboard 卡片点击：sheet 75% 高度，下滑关闭
//  - Decisions Tab：全屏铺满 UpgradePromptView
//

import SwiftUI

// MARK: - PremiumGateModifier

struct PremiumGateModifier: ViewModifier {
    let featureKey: PremiumFeatureKey
    @Environment(AppState.self) private var appState
    @State private var showUpgradePrompt: Bool = false

    private var isEnabled: Bool {
        appState.premiumEnabledFlags[featureKey.rawValue] ?? false
    }

    func body(content: Content) -> some View {
        Button {
            if isEnabled { return }
            showUpgradePrompt = true
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
                .presentationDetents([.fraction(0.75)])
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

struct PremiumBadge: View {
    var body: some View {
        Text("PREMIUM")
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

// MARK: - View Extension

extension View {
    func premiumGate(feature: PremiumFeatureKey) -> some View {
        modifier(PremiumGateModifier(featureKey: feature))
    }
}

// MARK: - UpgradePromptView

struct UpgradePromptView: View {
    let featureKey: PremiumFeatureKey
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme

    /// 当前 Premium 功能列表
    private let premiumFeatures: [(icon: String, name: String)] = [
        ("chart.line.uptrend.xyaxis", "Trend Prediction & Growth Forecast"),
        ("bolt.fill", "Activity & Retention Analysis"),
        ("star.fill", "Engagement Quality Scoring"),
        ("globe.asia.australia.fill", "Geo Distribution"),
        ("checkmark.shield", "Authenticity Assessment"),
        ("calendar.badge.clock", "Best Time to Post (Heatmap)"),
        ("arrow.left.arrow.right", "Campaign Tracking"),
        ("sparkle.magnifyingglass", "Growth Decisions Engine"),
        ("bubble.left.and.bubble.right", "Comment Management"),
        ("doc.richtext.fill", "Media Kit Export"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 皇冠图标
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.chartBarGradientStart, theme.chartBarGradientEnd],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .padding(.bottom, 16)

            // 标题
            Text(loc(L10n.Premium.premiumFeature))
                .font(.title2).fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
                .padding(.bottom, 4)

            Text(featureKey.displayName)
                .font(.subheadline)
                .foregroundColor(theme.accentPrimary)
                .padding(.bottom, 24)

            // Premium 功能卡片列表
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(premiumFeatures, id: \.icon) { feature in
                        VStack(spacing: 8) {
                            Image(systemName: feature.icon)
                                .font(.title3)
                                .foregroundColor(theme.accentPrimary)
                            Text(feature.name)
                                .font(.system(size: 10))
                                .foregroundColor(theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 280)

            Spacer()

            // 底部操作区
            VStack(spacing: 12) {
                if appState.isTrialActive {
                    Text(loc(L10n.Premium.trialActive))
                        .font(.caption).foregroundColor(.secondary)
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
                                    colors: [theme.chartBarGradientStart, theme.chartBarGradientEnd],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)

                    Text(loc(L10n.Premium.comingSoon))
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundGradientStart)
    }
}

#Preview {
    UpgradePromptView(featureKey: .trendPrediction)
        .environment(AppState(databaseManager: DatabaseManager.shared))
}
