//
//  Glass.swift
//  Follower
//
//  Created by Zane Liao on 8/1/26.
//

import SwiftUI

// 和弦数据模型
struct Chord: Identifiable {
    let id = UUID()
    let name: String
    let notes: String
    let isMajor: Bool
}

// 卡片视图（每个和弦一张卡片）
struct ChordCardView: View {
    let chord: Chord

    var body: some View {
        HStack {
            // 左侧图标：根据大小调显示不同符号
            Image(systemName: chord.isMajor ? "guitars.fill" : "guitars")
                .font(.title2)
                .foregroundStyle(chord.isMajor ? .yellow : .cyan)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(chord.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(chord.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 80)                     // 统一高度
        .glassEffect(
            .regular
                .tint(.blue.opacity(0.12))
                .interactive()
        )
    }
}

// 主视图：分组展示
struct ChordListView: View {
    // 数据分组
    let firstChords: [Chord] = [
        Chord(name: "C major", notes: "C, E, G", isMajor: true),
        Chord(name: "G major", notes: "G, B, D", isMajor: true),
        Chord(name: "D major", notes: "D, F#, A", isMajor: true),
        Chord(name: "A major", notes: "A, C#, E", isMajor: true),
        Chord(name: "E major", notes: "E, G#, B", isMajor: true),
        Chord(name: "A minor", notes: "A, C, E", isMajor: false),
        Chord(name: "E minor", notes: "E, G, B", isMajor: false),
        Chord(name: "D minor", notes: "D, F, A", isMajor: false),
        Chord(name: "E7", notes: "E, G#, B, D", isMajor: false),
        Chord(name: "G7", notes: "G, B, D, F", isMajor: false)
    ]

    let exploreChords: [Chord] = [
        Chord(name: "音乐包", notes: "流行、民谣常用", isMajor: true),
        Chord(name: "爵士和弦集", notes: "丰富和声色彩", isMajor: false)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 第一部分：第一个和弦
                Text("第一个和弦")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                VStack(spacing: 12) {
                    ForEach(firstChords) { chord in
                        ChordCardView(chord: chord)
                            .padding(.horizontal, 16)
                    }
                }

                Divider()
                    .padding(.horizontal, 16)

                // 第二部分：探索和弦包
                Text("探索和弦包")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 16)

                VStack(spacing: 12) {
                    ForEach(exploreChords) { chord in
                        ChordCardView(chord: chord)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(
            // 背景用渐变 + 装饰圆，展示玻璃穿透效果
            LinearGradient(
                colors: [.blue.opacity(0.25), .purple.opacity(0.25), .pink.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

#Preview {
    ChordListView()
}
