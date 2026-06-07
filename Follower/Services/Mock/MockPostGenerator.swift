//
//  MockPostGenerator.swift
//  Follower
//
//  Lambda: 生成 Mock 帖子数据。

import Foundation

enum PostType: String, CaseIterable, Sendable {
    case image = "photo"
    case video = "video.fill"
    case carousel = "square.on.square"
}

struct MockPost: Identifiable, Sendable {
    let id: String
    let type: PostType
    let date: Date
    let likes: Int
    let comments: Int
    let reach: Int
    let saves: Int
    let caption: String
    let colorHex: String

    var formattedLikes: String { likes >= 1000 ? String(format: "%.1fK", Double(likes) / 1000) : "\(likes)" }
    var formattedReach: String { reach >= 1000 ? String(format: "%.1fK", Double(reach) / 1000) : "\(reach)" }
}

struct MockPostGenerator: Sendable {
    private let captions = [
        "Sunset vibes 🌅", "New recipe just dropped!", "Morning coffee routine ☕",
        "Behind the scenes", "Throwback to summer", "Weekend getaway",
        "New outfit check", "Work hard play hard", "Self-care Sunday",
        "Travel diary entry", "Fitness journey update", "Late night thoughts",
        "OOTD: casual edition", "Food porn incoming", "Studio session",
    ]
    private let colors = ["#E85D75", "#4ECDC4", "#FF6B6B", "#45B7D1", "#96CEB4",
                           "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE"]

    func generate(count: Int = 5) -> [MockPost] {
        var posts: [MockPost] = []
        for i in 0..<count {
            let daysAgo = i + Int.random(in: 0...2)
            posts.append(MockPost(
                id: UUID().uuidString,
                type: PostType.allCases.randomElement()!,
                date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date(),
                likes: Int.random(in: 50...5000),
                comments: Int.random(in: 5...200),
                reach: Int.random(in: 500...50000),
                saves: Int.random(in: 2...100),
                caption: captions.randomElement()!,
                colorHex: colors.randomElement()!
            ))
        }
        return posts.sorted { $0.date > $1.date }
    }
}
