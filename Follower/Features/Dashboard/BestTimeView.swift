//
//  BestTimeView.swift
//  Follower
//
//  Lambda: Premium 详情 — 最佳发帖时间（Mock 热力图）。

import SwiftUI

/// Premium 详情页：展示最佳发帖时间与每小时互动热力图
struct BestTimeView: View {
    /// 星期标签
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    /// 24 小时数组
    private let hours = Array(0..<24)
    /// 预生成的 Mock 热力图数据
    private let heatmap = BestTimeView.generateHeatmap()

    /// 最佳发帖时间 + 热力图 UI
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 推荐最佳时间卡片
                VStack(spacing: 4) {
                    Text("📅 Wednesday 7 PM").font(.title2).fontWeight(.bold)
                    Text("Your best posting time").font(.subheadline).foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // 热力图区域
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hourly Engagement Heatmap").font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 24), spacing: 1) {
                        ForEach(0..<7, id: \.self) { day in
                            ForEach(0..<24, id: \.self) { hour in
                                let val = heatmap[day][hour]
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.orange.opacity(val))
                                    .frame(height: 14)
                            }
                        }
                    }
                    .padding(8)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // 热力图图例：低到高
                HStack(spacing: 4) {
                    Text("Low").font(.caption2).foregroundColor(.secondary)
                    RoundedRectangle(cornerRadius: 1).fill(Color.orange.opacity(0.1)).frame(width: 12, height: 12)
                    RoundedRectangle(cornerRadius: 1).fill(Color.orange.opacity(0.5)).frame(width: 12, height: 12)
                    RoundedRectangle(cornerRadius: 1).fill(Color.orange.opacity(1.0)).frame(width: 12, height: 12)
                    Text("High").font(.caption2).foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Best Time to Post")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 生成 7x24 Mock 热力图数据，值域 [0, 1]
    static func generateHeatmap() -> [[Double]] {
        (0..<7).map { _ in (0..<24).map { _ in Double.random(in: 0...1) } }
    }
}
