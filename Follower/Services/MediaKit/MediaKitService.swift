//
//  MediaKitService.swift
//  Follower
//
//  媒体包服务门面 — 数据收集（MediaKitDataProvider）+ PDF 生成（MediaKitPDFGenerator）
//  的组合入口，供 ViewModel 调用。生成全程可后台执行。
//

import Foundation

// MARK: - Protocol

protocol MediaKitServiceProtocol: Sendable {
    func generateMediaKit(accountId: Int64, template: MediaKitTemplate) async throws -> URL
}

// MARK: - Service

struct MediaKitService: MediaKitServiceProtocol {
    private let provider: MediaKitDataProviding
    private let generator: MediaKitPDFGenerating

    init(
        provider: MediaKitDataProviding = MediaKitDataProvider(
            accountRepo: AccountRepository(db: DatabaseManager.shared),
            snapshotRepo: SnapshotRepository(db: DatabaseManager.shared),
            metricRepo: MetricRepository(db: DatabaseManager.shared),
            mediaRepo: MediaPostRepository(db: DatabaseManager.shared)
        ),
        generator: MediaKitPDFGenerating = MediaKitPDFGenerator()
    ) {
        self.provider = provider
        self.generator = generator
    }

    /// 生成媒体包 PDF 并返回文件 URL（调用方负责展示与分享）
    func generateMediaKit(accountId: Int64, template: MediaKitTemplate = .professional) async throws -> URL {
        let data = try await provider.collect(accountId: accountId)
        return try generator.generate(data: data, template: template)
    }
}
