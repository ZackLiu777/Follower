//
//  MediaPost.swift
//  Follower
//
//  UI 层帖子模型（由 Instagram API IGMedia 映射而来）。
//  v4 起持久化到 media_post 表（原仅内存缓存，App 重启后帖子消失）。
//

import Foundation
import GRDB

enum MediaPostType: String, Sendable, Codable, DatabaseValueConvertible {
    case image, video, carousel
}

struct MediaPost: Identifiable, Sendable, Codable, FetchableRecord, PersistableRecord {
    let id: Int64
    let accountId: Int64
    let igMediaID: String
    let type: MediaPostType
    let date: Date
    let likes: Int
    let comments: Int
    let caption: String
    let mediaURL: String?
    let permalink: String?

    static let databaseTableName = "media_post"

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

// MARK: - Column Names

extension MediaPost {
    /// GRDB 列名映射
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let accountId = Column(CodingKeys.accountId)
        static let igMediaID = Column(CodingKeys.igMediaID)
        static let type = Column(CodingKeys.type)
        static let date = Column(CodingKeys.date)
        static let likes = Column(CodingKeys.likes)
        static let comments = Column(CodingKeys.comments)
        static let caption = Column(CodingKeys.caption)
        static let mediaURL = Column(CodingKeys.mediaURL)
        static let permalink = Column(CodingKeys.permalink)
    }
}

// MARK: - DerivableRequest

extension DerivableRequest<MediaPost> {
    /// 按账号 ID 过滤
    func filter(accountId: Int64) -> Self {
        filter(MediaPost.Columns.accountId == accountId)
    }
}
