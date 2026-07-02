//
//  GeoDetailView.swift
//  Follower
//
//  Gamma: Premium 详情 — 粉丝地域分布。

import SwiftUI

/// Premium 详情页：展示粉丝地域分布，含国旗 + 地区名 + 占比横向柱状图
struct GeoDetailView: View {
    /// 主题环境
    @Environment(\.theme) private var theme

    /// 地域分布分析结果
    let result: GeoDistributionResult?

    /// 各地区横向柱状图 + 顶部地区高亮 UI
    var body: some View {
        ZStack {
            // Theme background gradient
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            if let result = result {
                ScrollView {
                    VStack(spacing: 20) {
                        // 顶部地区 Hero 卡片
                        if let top = result.topRegion {
                            VStack(spacing: 4) {
                                Text(top.flag).font(.system(size: 48))
                                Text(top.name)
                                    .font(.title2).fontWeight(.bold)
                                Text(String(format: "%.1f%%", top.percentage))
                                    .font(.headline)
                                    .foregroundColor(theme.accentPrimary)
                                Text("Top Region").font(.caption).foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal)
                        }

                        // 地区分布列表
                        VStack(spacing: 12) {
                            Text("Distribution by Region")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(result.regions, id: \.name) { region in
                                geoBar(region: region)
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // 地区总数
                        Text("\(result.totalRegions) regions with measurable audience")
                            .font(.caption).foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .scrollContentBackground(.hidden)
            } else {
                // 无数据占位
                ContentUnavailableView(
                    "No Data Available",
                    systemImage: "globe",
                    description: Text("Geo distribution data will appear here once available.")
                )
            }
        }
        .navigationTitle(loc(L10n.Premium.geoDistribution))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helper Views

    /// 单个地区的横向柱状图：国旗 + 名称 + 占比 + 进度条
    private func geoBar(region: GeoRegion) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(region.flag).font(.title3)
                Text(region.name)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1f%%", region.percentage))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(theme.accentPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.divider)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [theme.accentPrimary, theme.accentPrimary.opacity(0.6)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * (region.percentage / 100.0))
                }
            }
            .frame(height: 10)
        }
    }
}
