//
//  MediaPost.swift
//  Follower
//
//  UI 层帖子模型（由 Instagram API IGMedia 映射而来）。
//

import Foundation

enum MediaPostType: String, Sendable {
    case image, video, carousel
}

struct MediaPost: Identifiable, Sendable {
    let id: Int64
    let igMediaID: String
    let type: MediaPostType
    let date: Date
    let likes: Int
    let comments: Int
    let caption: String
    let mediaURL: String?
    let permalink: String?

    var formattedLikes: String {
        likes >= 1000 ? String(format: "%.1fK", Double(likes) / 1000) : "\(likes)"
    }

    var typeIconName: String {
        switch type {
        case .image: return "photo"
        case .video: return "video.fill"
        case .carousel: return "square.on.square"
        }
    }

    var colorHex: String {
        switch type {
        case .image: return "#E85D75"
        case .video: return "#4ECDC4"
        case .carousel: return "#FF6B6B"
        }
    }
}
