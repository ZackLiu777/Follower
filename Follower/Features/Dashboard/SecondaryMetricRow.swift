//
//  SecondaryMetricRow.swift
//  Follower
//
//  Lambda: Dashboard 次要指标，一行三列。

import SwiftUI

struct SecondaryMetricItem: View {
    let title: String
    let value: String
    let delta: String
    let isPositive: Bool
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3).fontWeight(.bold)
            HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                    .font(.caption2)
                Text(delta)
                    .font(.caption)
            }
            .foregroundColor(isPositive ? .green : .red)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SecondaryMetricRow: View {
    let engagementRate: Double
    let reach: Int
    let posts: Int
    let engagementDelta: Double
    let reachDelta: Int
    let postsDelta: Int

    var body: some View {
        HStack(spacing: 10) {
            SecondaryMetricItem(
                title: loc(L10n.Dashboard.engagementRate),
                value: String(format: "%.1f%%", engagementRate * 100),
                delta: String(format: "%+.1f%%", engagementDelta * 100),
                isPositive: engagementDelta >= 0, tint: .pink
            )
            SecondaryMetricItem(
                title: "Reach",
                value: reach >= 1000 ? String(format: "%.1fK", Double(reach) / 1000) : "\(reach)",
                delta: "\(reachDelta >= 0 ? "+" : "")\(reachDelta)",
                isPositive: reachDelta >= 0, tint: .blue
            )
            SecondaryMetricItem(
                title: loc(L10n.Dashboard.media),
                value: "\(posts)",
                delta: "\(postsDelta >= 0 ? "+" : "")\(postsDelta)",
                isPositive: postsDelta >= 0, tint: .orange
            )
        }
    }
}

#Preview {
    SecondaryMetricRow(engagementRate: 0.042, reach: 89000, posts: 52, engagementDelta: 0.003, reachDelta: 1200, postsDelta: 3)
        .padding()
}
