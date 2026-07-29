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

    // MARK: - API Layer

    let apiClient: InstagramAPIClientProtocol
    let tokenProvider: TokenProviderProtocol

    // MARK: - Core Services

    let aggregationService: AggregationServiceProtocol
    let ingestionService: IngestionServiceProtocol
    let syncEngine: SyncEngineProtocol

    // MARK: - Export & Trial

    let exportService: ExportServiceProtocol
    let trialManager: TrialManagerProtocol

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

        self.accountRepository = accountRepo
        self.eventRepository = eventRepo
        self.snapshotRepository = snapshotRepo
        self.metricRepository = metricRepo
        self.premiumFeatureRepository = premiumRepo

        // API Layer
        let client = InstagramAPIClient()
        let tokenProv = TokenProvider()
        self.apiClient = client
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
            apiClient: client,
            tokenProvider: tokenProv
        )
        self.syncEngine = sync

        self.exportService = ExportService(
            snapshotRepo: snapshotRepo, metricRepo: metricRepo, eventRepo: eventRepo
        )

        self.trialManager = TrialManager(premiumFeatureRepo: premiumRepo)

        // Premium Services
        self.scoringService = ScoringService()
        self.comparisonService = ComparisonService()
        self.predictionService = PredictionService()
        self.activityAnalysisService = ActivityAnalysisService()
        self.retentionAnalysisService = RetentionAnalysisService()
        self.geoDistributionService = GeoDistributionService(apiClient: client, tokenProvider: tokenProv)
        self.aiAnalysisService = AIAnalysisService()
        self.authenticityService = AuthenticityService()
        self.campaignComparisonService = CampaignComparisonService()
        self.engagementHeatmapService = EngagementHeatmapService()
    }
}
