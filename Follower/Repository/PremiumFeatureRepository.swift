//
//  PremiumFeatureRepository.swift
//  Follower
//
//  Premium 功能开关数据访问层。
//  Alpha 阶段保留完整接口，默认所有 Premium 功能关闭。
//

import Foundation
import GRDB

// MARK: - PremiumFeatureRepositoryProtocol

/// Premium 功能开关数据访问协议，Alpha 阶段默认全部关闭
protocol PremiumFeatureRepositoryProtocol: Sendable {
    /// 获取全部 Premium 功能开关记录
    func fetchAll() async throws -> [PremiumFeature]
    /// 按功能 Key 查询单条开关记录
    func fetch(key: PremiumFeatureKey) async throws -> PremiumFeature?
    /// 判断某个 Premium 功能是否已启用（含过期检查）
    func isEnabled(key: PremiumFeatureKey) async throws -> Bool
    /// 设置功能开关，不限过期时间
    func setEnabled(_ enabled: Bool, for key: PremiumFeatureKey) async throws
    /// 设置功能开关，可选过期时间
    func setEnabled(_ enabled: Bool, expiresAt: Date?, for key: PremiumFeatureKey) async throws
}

// MARK: - PremiumFeatureRepository

/// PremiumFeatureRepository 实现，基于 GRDB 管理 Premium 功能开关状态
final class PremiumFeatureRepository: PremiumFeatureRepositoryProtocol {
    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    /// 查询全部 Premium 功能开关
    func fetchAll() async throws -> [PremiumFeature] {
        try await db.read { db in
            try PremiumFeature.fetchAll(db)
        }
    }

    /// 按 key 查询单条功能开关记录
    func fetch(key: PremiumFeatureKey) async throws -> PremiumFeature? {
        try await db.read { db in
            try PremiumFeature
                .filter(PremiumFeature.Columns.key == key)
                .fetchOne(db)
        }
    }

    /// 判断某个 Premium 功能是否启用（同时检查过期）
    func isEnabled(key: PremiumFeatureKey) async throws -> Bool {
        try await db.read { db in
            guard let feature = try PremiumFeature
                .filter(PremiumFeature.Columns.key == key)
                .fetchOne(db)
            else { return false }

            guard feature.enabled else { return false }

            // 如果设置了过期时间且已过期，返回 false
            if let expiresAt = feature.expiresAt, expiresAt <= Date() {
                return false
            }

            return true
        }
    }

    /// 快捷设置功能开关，无过期时间
    func setEnabled(_ enabled: Bool, for key: PremiumFeatureKey) async throws {
        try await setEnabled(enabled, expiresAt: nil, for: key)
    }

    /// 设置功能开关，支持过期时间（用于试用期控制）
    func setEnabled(_ enabled: Bool, expiresAt: Date?, for key: PremiumFeatureKey) async throws {
        try await db.write { db in
            _ = try PremiumFeature
                .filter(PremiumFeature.Columns.key == key)
                .updateAll(db, [
                    PremiumFeature.Columns.enabled.set(to: enabled),
                    PremiumFeature.Columns.expiresAt.set(to: expiresAt),
                ])
        }
    }
}
