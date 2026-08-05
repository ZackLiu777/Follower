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

/// 数据导出服务协议：支持 JSON / CSV / Excel 导出
protocol ExportServiceProtocol: Sendable {
    /// 导出 Snapshot + Metric 为 JSON 文件
    func exportAsJSON(accountId: Int64) async throws -> URL
    /// 导出 Snapshot 为 CSV 文件
    func exportAsCSV(accountId: Int64) async throws -> URL
    /// 仅导出 Snapshot 数组为 JSON 文件
    func exportSnapshotsJSON(accountId: Int64) async throws -> URL
    /// Gamma: Excel 导出（Premium）— UTF-8 BOM CSV，Excel 可直接打开
    func exportAsExcel(accountId: Int64) async throws -> URL
}

// MARK: - ExportService

/// 导出服务实现：将数据库数据序列化为文件并写入临时目录
final class ExportService: ExportServiceProtocol {
    private let snapshotRepo: SnapshotRepositoryProtocol
    private let metricRepo: MetricRepositoryProtocol
    private let eventRepo: EventRepositoryProtocol

    /// 注入 Snapshot / Metric / Event 三个 Repository
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

    /// 导出 Snapshot + Metric 为带格式的 JSON 文件（ISO 8601 日期）
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

    /// 仅导出 Snapshot 数据为 JSON（不含 Metric）
    func exportSnapshotsJSON(accountId: Int64) async throws -> URL {
        let snapshots = try await snapshotRepo.fetchAll(accountId: accountId)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshots)
        return try writeToTempFile(data: data, prefix: "follower_snapshots", extension: "json")
    }

    // MARK: - CSV Export

    /// 导出 Snapshot 为 CSV 文件（逗号分隔，ISO 8601 日期）
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

    // MARK: - Excel Export (Gamma Premium)

    /// Premium：导出带 UTF-8 BOM 的 CSV，Excel 可直接打开
    func exportAsExcel(accountId: Int64) async throws -> URL {
        let snapshots = try await snapshotRepo.fetchAll(accountId: accountId)

        // UTF-8 BOM ensures Excel opens correctly
        let BOM = "\u{FEFF}"
        var csv = BOM + "Date,Followers,Following,Media,Engagement Rate,Likes,Comments,Shares,Views\n"
        let formatter = ISO8601DateFormatter()

        for s in snapshots {
            let date = formatter.string(from: s.observedAt)
            csv += "\(date),\(s.followersCount),\(s.followingCount),\(s.mediaCount),\(String(format: "%.4f", s.engagementRate)),\(s.totalLikes),\(s.totalComments),\(s.totalShares),\(s.totalViews)\n"
        }

        guard let data = csv.data(using: .utf8) else {
            throw ExportError.encodingFailure
        }

        return try writeToTempFile(data: data, prefix: "follower_premium", extension: "csv")
    }

    // MARK: - Private

    /// 将 Data 写入临时目录，返回文件 URL
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

/// 导出操作错误类型
enum ExportError: Error {
    case encodingFailure
    case noData
}
