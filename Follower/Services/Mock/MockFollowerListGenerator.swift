//
//  MockFollowerListGenerator.swift
//  Follower
//
//  Lambda: 生成 Mock 取关/粉丝列表。

import Foundation

/// Mock 粉丝 / 取关用户数据：用户名 / 显示名 / 头像颜色 / 日期 / 是否取关
struct MockFollower: Identifiable, Sendable {
    let id: String
    let username: String
    let displayName: String
    let avatarColor: String
    let date: Date
    let isUnfollow: Bool
}

/// Mock 取关列表生成器（Lambda）：用于 UI 预览和 Alpha 测试
struct MockFollowerListGenerator: Sendable {
    private let usernames = [
        "emma.wilson", "alex.martinez", "sophia.chen", "james.lee", "olivia.park",
        "noah.johnson", "ava.garcia", "liam.brown", "mia.davis", "lucas.taylor",
        "isabella.white", "ethan.harris", "charlotte.king", "mason.wright",
    ]

    /// 生成指定数量的模拟取关用户，按日期降序排列
    func generateUnfollows(count: Int = 5) -> [MockFollower] {
        var followers: [MockFollower] = []
        for i in 0..<count {
            followers.append(MockFollower(
                id: UUID().uuidString,
                username: usernames.randomElement()! + "\(i)",
                displayName: usernames.randomElement()!.split(separator: ".").joined(separator: " ").capitalized,
                avatarColor: ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7"].randomElement()!,
                date: Calendar.current.date(byAdding: .day, value: -Int.random(in: 0...6), to: Date()) ?? Date(),
                isUnfollow: true
            ))
        }
        return followers.sorted { $0.date > $1.date }
    }
}
