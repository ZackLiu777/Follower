//
//  EngagementDetailView.swift
//  Follower
//
//  Lambda: 互动详情页 — 互动率趋势 + 维度分解。

import SwiftUI
import Charts

struct EngagementDetailView: View {
    let engagementRate: Double
    let likes: Int
    let comments: Int
    let shares: Int
    let views: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Rate hero
                VStack(spacing: 4) {
                    Text(String(format: "%.1f%%", engagementRate * 100))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("Engagement Rate").font(.subheadline).foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)

                // Breakdown
                VStack(spacing: 12) {
                    Text("Breakdown").font(.headline)
                    engagementBar(label: "Likes", value: likes, total: views, color: .pink)
                    engagementBar(label: "Comments", value: comments, total: views, color: .blue)
                    engagementBar(label: "Shares", value: shares, total: views, color: .teal)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Mock daily engagement chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Engagement").font(.headline).padding(.horizontal)
                    Chart {
                        ForEach(Array(MockEngagementGenerator.daily().enumerated()), id: \.0) { i, val in
                            BarMark(x: .value("", i), y: .value("", val))
                                .foregroundStyle(.pink.opacity(0.6))
                        }
                    }
                    .frame(height: 160)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Engagement")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func engagementBar(label: String, value: Int, total: Int, color: Color) -> some View {
        let rate = total > 0 ? Double(value) / Double(total) : 0
        return VStack(spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(String(format: "%.1f%%", rate * 100)).font(.subheadline).fontWeight(.medium)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geo.size.width * rate)
            }
            .frame(height: 8)
        }
    }
}

private enum MockEngagementGenerator {
    static func daily() -> [Double] {
        (0..<7).map { _ in Double.random(in: 0.01...0.08) }
    }
}

#Preview {
    NavigationStack {
        EngagementDetailView(engagementRate: 0.042, likes: 5000, comments: 300, shares: 100, views: 89000)
    }
}
