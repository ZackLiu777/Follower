//
//  MockFollowerListGenerator.swift
//  Follower
//
//  Lambda: 生成 Mock 取关/粉丝列表。

import Foundation

struct MockFollower: Identifiable, Sendable {
    let id: String
    let username: String
    let displayName: String
    let avatarColor: String
    let date: Date
    let isUnfollow: Bool
}

struct MockFollowerListGenerator: Sendable {
    private let usernames = [
        "emma.wilson", "alex.martinez", "sophia.chen", "james.lee", "olivia.park",
        "noah.johnson", "ava.garcia", "liam.brown", "mia.davis", "lucas.taylor",
        "isabella.white", "ethan.harris", "charlotte.king", "mason.wright",
    ]

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
