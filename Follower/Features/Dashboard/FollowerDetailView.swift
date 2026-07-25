//
//  FollowerDetailView.swift
//  Follower
//
//  Lambda: 粉丝详情页 — 增长曲线 + Mock 粉丝动态。

import SwiftUI
import Charts

/// 粉丝详情页：展示粉丝总数 Hero、7 天增长曲线、最近关注/取关动态
struct FollowerDetailView: View {
    @Environment(\.theme) private var theme

    /// 当前粉丝总数
    let currentFollowers: Int
    /// 7 天粉丝变化量
    let delta: Int
    /// 7 天粉丝变化百分比
    let deltaPercent: Double
    /// 7 天 Mini 折线图数据
    let sparklineData: [Double]
    /// 当前账户用户名（用于标题）
    let accountName: String
    let unfollowList: [UnfollowEntry]

    /// Hero 卡片 + 7 天增长曲线 + 最近动态列表 UI
    var body: some View {
        ZStack {
            // Theme background gradient
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Hero summary 卡片
                    VStack(spacing: 4) {
                        Text(currentFollowers.formatted(.number))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        HStack(spacing: 4) {
                            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text("\(delta >= 0 ? "+" : "")\(delta) (\(String(format: "%+.1f", deltaPercent))%)")
                        }
                        .font(.headline)
                        .foregroundColor(delta >= 0 ? theme.positiveGreen : theme.negativeRed)
                        Text("vs last 7 days").font(.caption).foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                    // 7 天增长曲线 Chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("7-Day Growth").font(.headline).padding(.horizontal)
                        Chart(Array(sparklineData.enumerated()), id: \.0) { i, val in
                            LineMark(x: .value("", i), y: .value("", val))
                                .foregroundStyle(theme.chartLine)
                            AreaMark(x: .value("", i), y: .value("", val))
                                .foregroundStyle(LinearGradient(colors: [theme.chartArea, .clear], startPoint: .top, endPoint: .bottom))
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    }

                    // Mock 粉丝动态列表
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Activity").font(.headline).padding(.horizontal)
                        ForEach(unfollowList) { f in
                            HStack {
                                ZStack {
                                    Circle().fill(Color.gray.opacity(0.3)).frame(width: 36, height: 36)
                                    Text(String(f.displayName.prefix(1))).font(.caption).foregroundColor(.white)
                                }
                                VStack(alignment: .leading) {
                                    Text(f.displayName).font(.subheadline).fontWeight(.medium)
                                    Text("@\(f.username)").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(f.isUnfollow ? "Unfollowed" : "Followed")
                                    .font(.caption)
                                    .foregroundColor(f.isUnfollow ? theme.negativeRed : theme.positiveGreen)
                            }
                            .padding(.horizontal)
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("\(accountName)'s Followers")
        .navigationBarTitleDisplayMode(.inline)
    }
}

