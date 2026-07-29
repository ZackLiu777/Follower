//
//  UnfollowEntry.swift
//  Follower
//
//  取关推算条目（基于本地 Snapshot diff，Instagram API 不支持取关列表）。
//

import Foundation

struct UnfollowEntry: Identifiable, Sendable {
    let id: String
    let username: String
    let displayName: String
    let date: Date
    let isUnfollow: Bool
}
