//
//  SyncEngine.swift
//  Follower
//
//  同步引擎，负责：
//  - 管理外部账号同步流程
//  - 处理授权状态
//  - 控制同步频率
//  - 执行增量同步与重试
//  Alpha 阶段使用模拟数据，不连接真实 API。
//

import Foundation

// MARK: - SyncEngineProtocol

protocol SyncEngineProtocol: Sendable {
    /// 执行单次全量同步
    func sync(accountId: Int64) async throws -> SyncResult
    /// 执行增量同步（自上次同步以来）
    func incrementalSync(accountId: Int64) async throws -> SyncResult
    /// 获取当前同步状态
    func syncStatus(accountId: Int64) async -> SyncStatus
}

// MARK: - SyncStatus

struct SyncStatus {
    enum State {
        case idle
        case syncing
        case success(lastSync: Date)
        case error(Error, lastAttempt: Date)
    }

    let state: State
    let accountId: Int64

    var isSyncing: Bool {
        if case .syncing = state { return true }
        return false
    }
}

// MARK: - SyncEngine

final actor SyncEngine: SyncEngineProtocol {
    private let eventRepo: EventRepositoryProtocol
    private let accountRepo: AccountRepositoryProtocol
    private let ingestionService: IngestionServiceProtocol

    /// 同步状态缓存
    private var statusCache: [Int64: SyncStatus.State] = [:]

    /// 最短同步间隔（秒）
    private let minSyncInterval: TimeInterval = 60

    init(
        eventRepo: EventRepositoryProtocol,
        accountRepo: AccountRepositoryProtocol,
        ingestionService: IngestionServiceProtocol
    ) {
        self.eventRepo = eventRepo
        self.accountRepo = accountRepo
        self.ingestionService = ingestionService
    }

    // MARK: - Public

    func sync(accountId: Int64) async throws -> SyncResult {
        statusCache[accountId] = .syncing

        do {
            // Alpha 阶段：使用模拟数据
            let mockProfile = generateMockProfile()
            let mockTrend = generateMockTrend()

            // 通过 Ingestion Service 转换为 Event
            let result = try await ingestionService.ingest(
                accountId: accountId,
                profile: mockProfile,
                trend: mockTrend
            )

            let state = SyncStatus.State.success(lastSync: Date())
            statusCache[accountId] = state

            return result
        } catch {
            statusCache[accountId] = .error(error, lastAttempt: Date())
            throw error
        }
    }

    func incrementalSync(accountId: Int64) async throws -> SyncResult {
        // 获取上次同步时间
        let latestEvent = try? await eventRepo.latestObservedAt(accountId: accountId)

        // 如果最近同步在一分钟内，跳过
        if let lastSync = latestEvent,
           Date().timeIntervalSince(lastSync) < minSyncInterval {
            return SyncResult(
                accountId: accountId,
                eventsCreated: 0,
                snapshotsUpdated: 0,
                metricsUpdated: 0,
                errors: []
            )
        }

        return try await sync(accountId: accountId)
    }

    func syncStatus(accountId: Int64) async -> SyncStatus {
        let state = statusCache[accountId] ?? .idle
        return SyncStatus(state: state, accountId: accountId)
    }

    // MARK: - Mock Data (Alpha)

    private func generateMockProfile() -> APIProfileResponse {
        APIProfileResponse(
            username: "demo_user",
            displayName: "Demo User",
            followersCount: Int.random(in: 500...5000),
            followingCount: Int.random(in: 100...500),
            mediaCount: Int.random(in: 20...200),
            totalLikes: Int.random(in: 1000...50000),
            totalComments: Int.random(in: 100...5000),
            totalShares: Int.random(in: 50...2000),
            totalViews: Int.random(in: 2000...100000),
            engagementRate: Double.random(in: 0.01...0.15),
            fetchedAt: Date()
        )
    }

    private func generateMockTrend() -> APITrendResponse {
        let calendar = Calendar.current
        let days = 30
        var dataPoints: [APITrendDataPoint] = []

        var followers = Double.random(in: 500...5000)

        for i in 0..<days {
            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let change = Double.random(in: -20...50)
            followers += change

            dataPoints.append(APITrendDataPoint(
                date: date,
                followersCount: Int(max(0, followers)),
                followingCount: Int.random(in: 100...500),
                mediaCount: Int.random(in: 20...200),
                engagementRate: Double.random(in: 0.01...0.15)
            ))
        }

        return APITrendResponse(
            username: "demo_user",
            dataPoints: dataPoints,
            period: "month"
        )
    }
}
