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

protocol PremiumFeatureRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [PremiumFeature]
    func fetch(key: PremiumFeatureKey) async throws -> PremiumFeature?
    func isEnabled(key: PremiumFeatureKey) async throws -> Bool
    func setEnabled(_ enabled: Bool, for key: PremiumFeatureKey) async throws
    func setEnabled(_ enabled: Bool, expiresAt: Date?, for key: PremiumFeatureKey) async throws
}

// MARK: - PremiumFeatureRepository

final class PremiumFeatureRepository: PremiumFeatureRepositoryProtocol {
    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    func fetchAll() async throws -> [PremiumFeature] {
        try await db.read { db in
            try PremiumFeature.fetchAll(db)
        }
    }

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

    func setEnabled(_ enabled: Bool, for key: PremiumFeatureKey) async throws {
        try await setEnabled(enabled, expiresAt: nil, for: key)
    }

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
