//
//  DraftPost.swift
//  Follower
//
//  发布助手草稿模型 — 文案 + 图片引用 + 可选排期时间 + 状态机。
//  发布动作交给系统分享面板 / 快捷指令，App 只负责准备内容与提醒。
//

import Foundation
import GRDB

// MARK: - DraftPostStatus

/// 草稿发布状态机：draft → scheduled → published；scheduled 逾期未处理保留待发布
enum DraftPostStatus: String, Codable, DatabaseValueConvertible, CaseIterable {
    case draft        // 草稿：已保存未排期
    case scheduled    // 已排期：到点本地通知提醒
    case published    // 已发布：用户确认完成后标记
    case failed       // 已取消 / 发布失败
}

// MARK: - DraftPost

/// 发布助手草稿 — 文案 + 图片引用 + 可选排期时间
struct DraftPost: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    /// 关联账号（可选：未连接账号也能写草稿）
    var accountId: Int64?
    var caption: String
    /// 沙盒内图片相对文件名（Documents/FollowerDrafts/ 下）
    var imageFilename: String?
    /// 排期时间（draft 状态为 nil）
    var scheduledAt: Date?
    var status: DraftPostStatus
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "draftPost"

    /// 插入成功后回填自增 rowID
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    /// 是否已到期待发布（scheduled 且时间已过）
    var isDue: Bool {
        guard status == .scheduled, let scheduledAt else { return false }
        return scheduledAt <= Date()
    }
}

// MARK: - Column Names

extension DraftPost {
    /// GRDB 列名映射，避免字符串硬编码
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let accountId = Column(CodingKeys.accountId)
        static let caption = Column(CodingKeys.caption)
        static let imageFilename = Column(CodingKeys.imageFilename)
        static let scheduledAt = Column(CodingKeys.scheduledAt)
        static let status = Column(CodingKeys.status)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

// MARK: - DerivableRequest

extension DerivableRequest<DraftPost> {
    /// 按状态过滤查询
    func filter(status: DraftPostStatus) -> Self {
        filter(DraftPost.Columns.status == status)
    }
}
