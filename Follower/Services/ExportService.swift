//
//  ExportService.swift
//  Follower
//
//  数据导出服务，负责：
//  - JSON 导出
//  - CSV 导出
//  所有导出操作必须由用户主动触发。
//

import Foundation

// MARK: - ExportServiceProtocol

protocol ExportServiceProtocol: Sendable {
    /// 导出为 JSON
    func exportAsJSON(accountId: Int64) async throws -> URL
    /// 导出为 CSV
    func exportAsCSV(accountId: Int64) async throws -> URL
    /// 导出 Snapshot 为 JSON
    func exportSnapshotsJSON(accountId: Int64) async throws -> URL
}

// MARK: - ExportService

final class ExportService: ExportServiceProtocol {
    private let snapshotRepo: SnapshotRepositoryProtocol
    private let metricRepo: MetricRepositoryProtocol
    private let eventRepo: EventRepositoryProtocol

    init(
        snapshotRepo: SnapshotRepositoryProtocol,
        metricRepo: MetricRepositoryProtocol,
        eventRepo: EventRepositoryProtocol
    ) {
        self.snapshotRepo = snapshotRepo
        self.metricRepo = metricRepo
        self.eventRepo = eventRepo
    }

    // MARK: - JSON Export

    func exportAsJSON(accountId: Int64) async throws -> URL {
        let snapshots = try await snapshotRepo.fetchAll(accountId: accountId)
        let metrics = try await metricRepo.fetch(accountId: accountId, window: .day, from: Date.distantPast, to: Date())

        let export = JSONExportData(
            exportedAt: Date(),
            accountId: accountId,
            snapshots: snapshots,
            metrics: metrics
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(export)

        return try writeToTempFile(data: data, prefix: "follower_export", extension: "json")
    }

    func exportSnapshotsJSON(accountId: Int64) async throws -> URL {
        let snapshots = try await snapshotRepo.fetchAll(accountId: accountId)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshots)
        return try writeToTempFile(data: data, prefix: "follower_snapshots", extension: "json")
    }

    // MARK: - CSV Export

    func exportAsCSV(accountId: Int64) async throws -> URL {
        let snapshots = try await snapshotRepo.fetchAll(accountId: accountId)

        var csv = "Date,Followers,Following,Media,EngagementRate,Likes,Comments,Shares,Views\n"
        let formatter = ISO8601DateFormatter()

        for s in snapshots {
            let date = formatter.string(from: s.observedAt)
            csv += "\(date),\(s.followersCount),\(s.followingCount),\(s.mediaCount),\(s.engagementRate),\(s.totalLikes),\(s.totalComments),\(s.totalShares),\(s.totalViews)\n"
        }

        guard let data = csv.data(using: .utf8) else {
            throw ExportError.encodingFailure
        }

        return try writeToTempFile(data: data, prefix: "follower_export", extension: "csv")
    }

    // MARK: - Private

    private func writeToTempFile(data: Data, prefix: String, extension ext: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "\(prefix)_\(Date().timeIntervalSince1970).\(ext)"
        let url = tempDir.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - Export Models

/// JSON 导出结构（与内部数据库隔离）
struct JSONExportData: Codable {
    let exportedAt: Date
    let accountId: Int64
    let snapshots: [Snapshot]
    let metrics: [Metric]
}

// MARK: - Export Errors

enum ExportError: Error {
    case encodingFailure
    case noData
}
