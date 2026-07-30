//
//  SyncEngine.swift
//  Follower
//
//  同步引擎 — Instagram API → IngestionService → AggregationService 数据管线。
//

import Foundation

// MARK: - SyncEngineProtocol

protocol SyncEngineProtocol: Sendable {
    func sync(accountId: Int64) async throws -> SyncResult
    func incrementalSync(accountId: Int64) async throws -> SyncResult
    func syncStatus(accountId: Int64) async -> SyncStatus
    func fetchRecentMedia(accountId: Int64, limit: Int) async throws -> [MediaPost]
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
    private let apiClient: InstagramAPIClientProtocol
    private let tokenProvider: TokenProviderProtocol

    private var statusCache: [Int64: SyncStatus.State] = [:]
    private var mediaCache: [Int64: [MediaPost]] = [:]
    private let minSyncInterval: TimeInterval = 60

    init(
        eventRepo: EventRepositoryProtocol,
        accountRepo: AccountRepositoryProtocol,
        ingestionService: IngestionServiceProtocol,
        apiClient: InstagramAPIClientProtocol,
        tokenProvider: TokenProviderProtocol
    ) {
        self.eventRepo = eventRepo
        self.accountRepo = accountRepo
        self.ingestionService = ingestionService
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
    }

    // MARK: - Public

    func sync(accountId: Int64) async throws -> SyncResult {
        statusCache[accountId] = .syncing

        // 尝试获取 token
        let token: String?
        do {
            token = try await tokenProvider.getToken(accountId: accountId)
        } catch is TokenError {
            token = nil
        }

        // 无 token：用 Account 数据库记录创建最小 Snapshot，使 Dashboard 进入 dataReady
        guard let token else {
            let account = try? await accountRepo.fetch(id: accountId)
            let profileDTO = APIProfileResponse(
                username: account?.username ?? "unknown",
                displayName: account?.displayName ?? "Unknown",
                followersCount: 0, followingCount: 0, mediaCount: 0,
                totalLikes: 0, totalComments: 0, totalShares: 0, totalViews: 0,
                engagementRate: 0, fetchedAt: Date()
            )
            let trendDTO = APITrendResponse(username: profileDTO.username, dataPoints: [], period: "day")
            let result = try await ingestionService.ingest(
                accountId: accountId, profile: profileDTO, trend: trendDTO
            )
            statusCache[accountId] = .success(lastSync: Date())
            return result
        }

        do {

            // 并行 3 次 API 调用
            async let igUser = apiClient.fetchProfile(accessToken: token)
            async let igInsights = apiClient.fetchInsights(
                accessToken: token,
                metrics: ["follower_count", "reach", "views"],
                period: "day"
            )
            async let igMedia = apiClient.fetchMedia(accessToken: token, limit: 25)

            let user = try await igUser
            let insights = try await igInsights
            let media = try await igMedia

            // 缓存媒体帖子
            mediaCache[accountId] = media.compactMap { m -> MediaPost? in
                let nid = Int64(m.id) ?? Int64(abs(m.id.hashValue))
                let date: Date = {
                    guard let ts = m.timestamp else { return Date() }
                    let iso = ISO8601DateFormatter()
                    let fb = DateFormatter()
                    fb.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                    fb.locale = Locale(identifier: "en_US_POSIX")
                    return iso.date(from: ts) ?? fb.date(from: ts) ?? Date()
                }()
                let ptype: MediaPostType = m.mediaType == "VIDEO" ? .video
                    : m.mediaType == "CAROUSEL_ALBUM" ? .carousel : .image
                return MediaPost(
                    id: nid, igMediaID: m.id, type: ptype, date: date,
                    likes: m.likeCount ?? 0, comments: m.commentsCount ?? 0,
                    caption: m.caption ?? "", mediaURL: nil, permalink: m.permalink
                )
            }

            // 媒体聚合
            let totalLikes = media.compactMap(\.likeCount).reduce(0, +)
            let totalComments = media.compactMap(\.commentsCount).reduce(0, +)
            let mediaCount = max(1, media.count)
            let avgLikes = totalLikes / mediaCount
            let avgComments = totalComments / mediaCount
            let followers = user.followersCount ?? 0
            let engagementRate = followers > 0 ? Double(avgLikes) / Double(followers) : 0

            let profileDTO = APIProfileResponse(
                username: user.username,
                displayName: user.name ?? user.username,
                followersCount: followers,
                followingCount: user.followsCount ?? 0,
                mediaCount: user.mediaCount ?? mediaCount,
                totalLikes: avgLikes,
                totalComments: avgComments,
                totalShares: 0,
                totalViews: 0,
                engagementRate: engagementRate,
                fetchedAt: Date()
            )

            let trendDTO = buildTrend(from: insights, username: user.username)

            let result = try await ingestionService.ingest(
                accountId: accountId,
                profile: profileDTO,
                trend: trendDTO
            )

            statusCache[accountId] = .success(lastSync: Date())
            return result
        } catch {
            statusCache[accountId] = .error(error, lastAttempt: Date())
            throw error
        }
    }

    func incrementalSync(accountId: Int64) async throws -> SyncResult {
        let latestEvent = try? await eventRepo.latestObservedAt(accountId: accountId)

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

    func fetchRecentMedia(accountId: Int64, limit: Int) async throws -> [MediaPost] {
        if let cached = mediaCache[accountId], !cached.isEmpty {
            return Array(cached.prefix(limit))
        }
        return []
    }
}

// MARK: - Insights Merge

/// 合并 follower_count / reach / impressions 三个时间序列为 APITrendResponse
private func buildTrend(from insights: [IGInsightValue], username: String) -> APITrendResponse {
    let iso = ISO8601DateFormatter()
    let fallback = DateFormatter()
    fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    fallback.locale = Locale(identifier: "en_US_POSIX")

    func parse(_ metricName: String) -> [Date: Double] {
        guard let insight = insights.first(where: { $0.name == metricName }),
              let values = insight.values else { return [:] }
        var dict: [Date: Double] = [:]
        for dp in values {
            guard let dateStr = dp.endTime, let value = dp.value,
                  let date = iso.date(from: dateStr) ?? fallback.date(from: dateStr) else { continue }
            dict[Calendar.current.startOfDay(for: date)] = value
        }
        return dict
    }

    let fSeries = parse("follower_count")
    let rSeries = parse("reach")
    let iSeries = parse("views")

    var allDays = Set(fSeries.keys)
    allDays.formUnion(rSeries.keys)
    allDays.formUnion(iSeries.keys)

    let points: [APITrendDataPoint] = allDays.sorted().map { day in
        let f = Int(fSeries[day] ?? 0)
        let imp = Int(iSeries[day] ?? 0)
        let er = f > 0 ? Double(imp) / Double(f) : 0
        return APITrendDataPoint(
            date: day, followersCount: f, followingCount: 0,
            mediaCount: 0, engagementRate: er, totalViews: imp
        )
    }

    return APITrendResponse(username: username, dataPoints: points, period: "day")
}
