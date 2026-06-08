//
//  PostRowView.swift
//  Follower
//
//  Lambda: 帖子列表行。

import SwiftUI

struct PostRowView: View {
    let post: MockPost

    var body: some View {
        HStack(spacing: 12) {
            // 缩略图占位
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: post.colorHex) ?? .gray)
                    .frame(width: 48, height: 48)
                Image(systemName: post.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(post.caption)
                    .font(.subheadline).lineLimit(1)
                Text(post.date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 16) {
                VStack(spacing: 1) {
                    Text(post.formattedLikes).font(.caption).fontWeight(.medium)
                    Image(systemName: "heart.fill").font(.caption2).foregroundColor(.pink)
                }
                VStack(spacing: 1) {
                    Text("\(post.comments)").font(.caption).fontWeight(.medium)
                    Image(systemName: "text.bubble.fill").font(.caption2).foregroundColor(.blue)
                }
                VStack(spacing: 1) {
                    Text(post.formattedReach).font(.caption).fontWeight(.medium)
                    Image(systemName: "eye.fill").font(.caption2).foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

extension Color {
    init?(hex: String) {
        let r, g, b: Double
        let start = hex.index(hex.startIndex, offsetBy: 1)
        let hexColor = String(hex[start...])
        guard hexColor.count == 6, let intVal = UInt64(hexColor, radix: 16) else { return nil }
        r = Double((intVal >> 16) & 0xFF) / 255
        g = Double((intVal >> 8) & 0xFF) / 255
        b = Double(intVal & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
