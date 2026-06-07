//
//  FollowerDetailView.swift
//  Follower
//
//  Lambda: 粉丝详情页 — 增长曲线 + Mock 粉丝动态。

import SwiftUI
import Charts

struct FollowerDetailView: View {
    let currentFollowers: Int
    let delta: Int
    let deltaPercent: Double
    let sparklineData: [Double]
    let accountName: String

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero summary
                VStack(spacing: 4) {
                    Text(currentFollowers.formatted(.number))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(delta >= 0 ? "+" : "")\(delta) (\(String(format: "%+.1f", deltaPercent))%)")
                    }
                    .font(.headline)
                    .foregroundColor(delta >= 0 ? .green : .red)
                    Text("vs last 7 days").font(.caption).foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)

                // Growth chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("7-Day Growth").font(.headline).padding(.horizontal)
                    Chart(Array(sparklineData.enumerated()), id: \.0) { i, val in
                        LineMark(x: .value("", i), y: .value("", val))
                            .foregroundStyle(.blue)
                        AreaMark(x: .value("", i), y: .value("", val))
                            .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                }

                // Mock follower activity
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Activity").font(.headline).padding(.horizontal)
                    ForEach(MockFollowerListGenerator().generateUnfollows(count: 6)) { f in
                        HStack {
                            ZStack {
                                Circle().fill(Color(hex: f.avatarColor) ?? .gray).frame(width: 36, height: 36)
                                Text(String(f.displayName.prefix(1))).font(.caption).foregroundColor(.white)
                            }
                            VStack(alignment: .leading) {
                                Text(f.displayName).font(.subheadline).fontWeight(.medium)
                                Text("@\(f.username)").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(f.isUnfollow ? "Unfollowed" : "Followed")
                                .font(.caption)
                                .foregroundColor(f.isUnfollow ? .red : .green)
                        }
                        .padding(.horizontal)
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("\(accountName)'s Followers")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        FollowerDetailView(currentFollowers: 12345, delta: 234, deltaPercent: 1.9, sparklineData: [90, 95, 102, 98, 105, 110, 108], accountName: "demo")
    }
}
