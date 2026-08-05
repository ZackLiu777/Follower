//
//  ContentStrategyView.swift
//  Follower
//
//  Phi: Premium 详情 — 内容策略建议（基于真实 AI 分析摘要）。
//

import SwiftUI

/// Premium 详情页：展示 AI 生成的策略建议 + 通用内容策略列表
struct ContentStrategyView: View {
    @Environment(\.theme) private var theme

    /// AI 分析摘要（由 AIAnalysisService 生成）
    let aiSummary: String

    /// 通用策略建议（本地化）
    private var strategyTips: [(icon: String, title: String, detail: String)] {
        [
            ("📷", loc(L10n.Premium.strategyCarousel), loc(L10n.Premium.strategyCarouselDesc)),
            ("🎬", loc(L10n.Premium.strategyVideo), loc(L10n.Premium.strategyVideoDesc)),
            ("🕐", loc(L10n.Premium.strategyFrequency), loc(L10n.Premium.strategyFrequencyDesc)),
            ("🏷️", loc(L10n.Premium.strategyHashtag), loc(L10n.Premium.strategyHashtagDesc)),
            ("💬", loc(L10n.Premium.strategyEngage), loc(L10n.Premium.strategyEngageDesc)),
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // AI 推荐
                    if !aiSummary.isEmpty {
                        VStack(spacing: 4) {
                            Text("💡 \(aiSummary)")
                                .font(.headline).multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // 策略列表
                    ForEach(strategyTips, id: \.title) { tip in
                        HStack(spacing: 12) {
                            Text(tip.icon).font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tip.title).font(.subheadline).fontWeight(.semibold)
                                Text(tip.detail).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.contentStrategy))
        .navigationBarTitleDisplayMode(.inline)
    }
}
