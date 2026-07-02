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

/// 同步引擎协议：管理外部账号的全量/增量同步与状态查询
protocol SyncEngineProtocol: Sendable {
    /// 执行单次全量同步
    func sync(accountId: Int64) async throws -> SyncResult
    /// 执行增量同步（自上次同步以来）
    func incrementalSync(accountId: Int64) async throws -> SyncResult
    /// 获取当前同步状态
    func syncStatus(accountId: Int64) async -> SyncStatus
}

// MARK: - SyncStatus

/// 同步状态：idle / syncing / success / error（含时间戳）
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

/// 同步引擎实现：actor 隔离保证同步状态线程安全，Alpha 阶段使用 Mock 数据
final actor SyncEngine: SyncEngineProtocol {
    private let eventRepo: EventRepositoryProtocol
    private let accountRepo: AccountRepositoryProtocol
    private let ingestionService: IngestionServiceProtocol

    /// 同步状态缓存（actor-isolated，保证线程安全）
    private var statusCache: [Int64: SyncStatus.State] = [:]

    /// 最短同步间隔（秒）
    private let minSyncInterval: TimeInterval = 60

    /// 注入 EventRepository / AccountRepository / IngestionService
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

    /// 执行单次全量同步：生成 Mock 数据 → Ingestion → 聚合（actor-isolated）
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

    /// 执行增量同步：检查上次同步时间，间隔不足 60s 则跳过（actor-isolated）
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

    /// 查询当前同步状态（actor-isolated 读操作）
    func syncStatus(accountId: Int64) async -> SyncStatus {
        let state = statusCache[accountId] ?? .idle
        return SyncStatus(state: state, accountId: accountId)
    }

    // MARK: - Mock Data (Alpha)

    /// 生成一整年逐日 Mock Trend 数据，每月趋势明显差异，便于年/月/周/日对比
    private func generateMockTrend() -> APITrendResponse {
        let calendar = Calendar.current
        let days = 365
        var dataPoints: [APITrendDataPoint] = []

        let startFollowers = Double.random(in: 1200...2500)
        var followers = startFollowers

        // 每月大致趋势：增长(+)、下降(-)、平稳(~)
        let monthlyTrend: [Double] = [
            3.5,    // Jan: 新年活动增长
            5.0,    // Feb: 持续增长
            -2.0,   // Mar: 小幅回调
            1.0,    // Apr: 平稳
            4.0,    // May: 春末增长
            6.5,    // Jun: 夏初高峰
            -3.0,   // Jul: 夏季低谷
            -1.5,   // Aug: 持续低迷
            2.5,    // Sep: 秋季回暖
            5.5,    // Oct: 金秋增长
            4.0,    // Nov: 节日季开始
            7.0,    // Dec: 年底高峰
        ]

        var pointIndex = days - 1
        for monthOffset in 0..<12 {
            let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: Date()) ?? Date()
            let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
            let baseTrend = monthlyTrend[11 - monthOffset]

            for day in 0..<daysInMonth {
                guard pointIndex >= 0 else { break }
                let date = calendar.date(byAdding: .day, value: -pointIndex, to: Date()) ?? Date()
                let dailyChange = baseTrend + Double.random(in: -8...12)
                followers = max(200, followers + dailyChange)

                let monthFactor = abs(baseTrend) / 7.0 + 0.5
                let baseLikes = followers * (0.8 + monthFactor * 0.4)
                let baseComments = followers * (0.05 + monthFactor * 0.03)

                dataPoints.append(APITrendDataPoint(
                    date: date,
                    followersCount: Int(followers),
                    followingCount: Int.random(in: 60...350),
                    mediaCount: Int.random(in: 8...120),
                    engagementRate: Double.random(in: 0.015...0.10) * (0.7 + monthFactor * 0.3)
                ))
                pointIndex -= 1
            }
        }

        return APITrendResponse(username: "demo_user", dataPoints: dataPoints, period: "year")
    }

    /// 生成随机 Mock Profile 数据（Alpha 阶段）
    private func generateMockProfile() -> APIProfileResponse {
        let followers = Int.random(in: 1200...2800)
        let engagement = Double.random(in: 0.025...0.09)
        return APIProfileResponse(
            username: "demo_user",
            displayName: "Demo User",
            followersCount: followers,
            followingCount: Int.random(in: 60...350),
            mediaCount: Int.random(in: 8...120),
            totalLikes: Int(followers) * Int(engagement * 150),
            totalComments: Int(followers) * Int(engagement * 15),
            totalShares: Int(followers) * Int(engagement * 8),
            totalViews: Int(followers) * Int(engagement * 200),
            engagementRate: engagement,
            fetchedAt: Date()
        )
    }
}
