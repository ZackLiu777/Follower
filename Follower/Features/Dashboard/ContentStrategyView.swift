//
//  ContentStrategyView.swift
//  Follower
//
//  Lambda: Premium 详情 — 内容策略建议（Mock）。

import SwiftUI

/// Premium 详情页：展示内容策略建议列表
struct ContentStrategyView: View {
    /// 当前推荐的核心策略标题
    let tip: String
    
    /// Mock 策略建议数据：(图标, 标题, 详细说明)
    private let tips: [(String, String, String)] = [
        ("📷", "Carousel Posts", "Get 2.3x more engagement than single images. Use 5-7 slides with a strong first image."),
        ("🎬", "Short Videos", "Videos under 15 seconds have 67% higher completion rate. Hook viewers in first 2 seconds."),
        ("🕐", "Post Frequency", "3-5 posts per week is optimal. Consistency matters more than volume."),
        ("🏷️", "Hashtag Strategy", "Use 5-10 relevant hashtags. Mix popular (1M+) with niche (10K-100K) for best reach."),
        ("💬", "Engage Back", "Reply to comments within 1 hour. Accounts that engage back see 40% higher loyalty."),
    ]
    
    /// 核心建议 + 策略列表 UI
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部推荐建议
                VStack(spacing: 4) {
                    Text("💡 \(tip)").font(.headline).multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                
                // 策略列表
                ForEach(tips, id: \.1) { (icon, title, detail) in
                    HStack(spacing: 12) {
                        Text(icon).font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title).font(.subheadline).fontWeight(.semibold)
                            Text(detail).font(.caption).foregroundColor(.secondary)
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
        .navigationTitle("Content Strategy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
