//
//  DIContainer.swift
//  Follower
//
//  依赖注入容器。
//  负责创建和持有所有 Repository 和 Service 实例。
//

import Foundation

@MainActor
@Observable
final class DIContainer {
    // MARK: - Repositories

    let accountRepository: AccountRepositoryProtocol
    let eventRepository: EventRepositoryProtocol
    let snapshotRepository: SnapshotRepositoryProtocol
    let metricRepository: MetricRepositoryProtocol
    let premiumFeatureRepository: PremiumFeatureRepositoryProtocol
    let draftPostRepository: DraftPostRepositoryProtocol

    // MARK: - API Layer

    /// 真实 Instagram API 客户端（账号连接验证等场景直连）
    let apiClient: InstagramAPIClientProtocol
    /// 全局唯一分派点 — 所有业务服务经它按 token 值选择 client（测试→mock，其余→real）
    let apiResolver: APIClientResolver
    let tokenProvider: TokenProviderProtocol

    // MARK: - Core Services

    let aggregationService: AggregationServiceProtocol
    let ingestionService: IngestionServiceProtocol
    let syncEngine: SyncEngineProtocol

    // MARK: - Export & Trial

    let exportService: ExportServiceProtocol
    let trialManager: TrialManagerProtocol

    // MARK: - 发布助手 & 评论管理

    let postAssistantService: PostAssistantService
    let commentService: CommentServiceProtocol

    // MARK: - Gamma Premium Services

    let scoringService: ScoringServiceProtocol
    let comparisonService: ComparisonServiceProtocol
    let predictionService: PredictionServiceProtocol
    let activityAnalysisService: ActivityAnalysisServiceProtocol
    let retentionAnalysisService: RetentionAnalysisServiceProtocol
    let geoDistributionService: GeoDistributionServiceProtocol
    let aiAnalysisService: AIAnalysisServiceProtocol

    // MARK: - Phi Premium Services

    let authenticityService: AuthenticityServiceProtocol
    let campaignComparisonService: CampaignComparisonServiceProtocol
    let engagementHeatmapService: EngagementHeatmapServiceProtocol

    // MARK: - Init

    init(databaseManager: DatabaseManager) {
        // Repositories
        let accountRepo = AccountRepository(db: databaseManager)
        let eventRepo = EventRepository(db: databaseManager)
        let snapshotRepo = SnapshotRepository(db: databaseManager)
        let metricRepo = MetricRepository(db: databaseManager)
        let premiumRepo = PremiumFeatureRepository(db: databaseManager)
        let draftPostRepo = DraftPostRepository(db: databaseManager)

        self.accountRepository = accountRepo
        self.eventRepository = eventRepo
        self.snapshotRepository = snapshotRepo
        self.metricRepository = metricRepo
        self.premiumFeatureRepository = premiumRepo
        self.draftPostRepository = draftPostRepo

        // API Layer
        // realClient：真实 Instagram API（OAuth / Token 账号专用）
        // mockClient：测试账号专用（哨兵 token 才可命中，见 APIClientResolver）
        let client = InstagramAPIClient()
        let mockClient = MockInstagramAPIClient()
        let resolver = APIClientResolver(realClient: client, mockClient: mockClient)
        // RoutingTokenProvider：测试账号（isTest）token 不落 Keychain（内存语义，创建永不因
        // Keychain 失败）；真实账号原样走 Keychain。各服务经协议引用，零改动。
        let tokenProv = RoutingTokenProvider(keychain: TokenProvider(), accountRepo: accountRepo)
        self.apiClient = client
        self.apiResolver = resolver
        self.tokenProvider = tokenProv

        // Core Services
        let aggregation = AggregationService(
            eventRepo: eventRepo, snapshotRepo: snapshotRepo, metricRepo: metricRepo
        )
        self.aggregationService = aggregation

        let ingestion = IngestionService(
            eventRepo: eventRepo, aggregationService: aggregation
        )
        self.ingestionService = ingestion

        let sync = SyncEngine(
            eventRepo: eventRepo,
            accountRepo: accountRepo,
            ingestionService: ingestion,
            apiResolver: resolver,
            tokenProvider: tokenProv
        )
        self.syncEngine = sync

        self.exportService = ExportService(
            snapshotRepo: snapshotRepo, metricRepo: metricRepo, eventRepo: eventRepo
        )

        self.trialManager = TrialManager(premiumFeatureRepo: premiumRepo)

        // 发布助手 & 评论管理
        self.postAssistantService = PostAssistantService()
        self.commentService = CommentService(apiResolver: resolver, tokenProvider: tokenProv)

        // Premium Services
        self.scoringService = ScoringService()
        self.comparisonService = ComparisonService()
        self.predictionService = PredictionService()
        self.activityAnalysisService = ActivityAnalysisService()
        self.retentionAnalysisService = RetentionAnalysisService()
        self.geoDistributionService = GeoDistributionService(apiResolver: resolver, tokenProvider: tokenProv)
        self.aiAnalysisService = AIAnalysisService()
        self.authenticityService = AuthenticityService()
        self.campaignComparisonService = CampaignComparisonService()
        self.engagementHeatmapService = EngagementHeatmapService()
    }
}
