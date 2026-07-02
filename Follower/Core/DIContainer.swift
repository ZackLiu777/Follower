//
//  DIContainer.swift
//  Follower
//
//  依赖注入容器。
//  负责创建和持有所有 Repository 和 Service 实例。
//  通过 AppState 暴露给 ViewModel 层。
//
//  依赖关系：
//  DatabaseManager
//    ├── AccountRepository
//    ├── EventRepository
//    ├── SnapshotRepository
//    ├── MetricRepository
//    └── PremiumFeatureRepository
//
//  Service Layer:
//    ├── AggregationService（依赖 Event/Snapshot/Metric Repo）
//    ├── IngestionService（依赖 EventRepo + AggregationService）
//    └── SyncEngine（依赖 EventRepo + AccountRepo + IngestionService）
//

import Foundation
import Combine

// DI 容器 — 单一入口创建并持有所有 Repository / Service / Premium 分析服务
@MainActor
final class DIContainer: ObservableObject {
    // MARK: - Repositories

    let accountRepository: AccountRepositoryProtocol
    let eventRepository: EventRepositoryProtocol
    let snapshotRepository: SnapshotRepositoryProtocol
    let metricRepository: MetricRepositoryProtocol
    let premiumFeatureRepository: PremiumFeatureRepositoryProtocol

    // MARK: - Services

    let aggregationService: AggregationServiceProtocol
    let ingestionService: IngestionServiceProtocol
    let syncEngine: SyncEngineProtocol

    // MARK: - Export Service

    let exportService: ExportServiceProtocol

    // MARK: - Trial Manager

    let trialManager: TrialManagerProtocol

    // MARK: - Init

    /// 构造 DI 容器，按依赖顺序创建 Repository → Service → Premium 分析服务
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

        // Services — 按依赖顺序创建
        let aggregation = AggregationService(
            eventRepo: eventRepo,
            snapshotRepo: snapshotRepo,
            metricRepo: metricRepo
        )
        self.aggregationService = aggregation

        let ingestion = IngestionService(
            eventRepo: eventRepo,
            aggregationService: aggregation
        )
        self.ingestionService = ingestion

        let sync = SyncEngine(
            eventRepo: eventRepo,
            accountRepo: accountRepo,
            ingestionService: ingestion
        )
        self.syncEngine = sync

        self.exportService = ExportService(
            snapshotRepo: snapshotRepo,
            metricRepo: metricRepo,
            eventRepo: eventRepo
        )

        self.trialManager = TrialManager(premiumFeatureRepo: premiumRepo)

        // Gamma: Premium analysis services
        self.scoringService = ScoringService()
        self.comparisonService = ComparisonService()
        self.predictionService = PredictionService()
        self.activityAnalysisService = ActivityAnalysisService()
        self.retentionAnalysisService = RetentionAnalysisService()
        self.geoDistributionService = GeoDistributionService()
        self.aiAnalysisService = AIAnalysisService()
    }

    // MARK: - Gamma Premium Services

    let scoringService: ScoringServiceProtocol
    let comparisonService: ComparisonServiceProtocol
    let predictionService: PredictionServiceProtocol
    let activityAnalysisService: ActivityAnalysisServiceProtocol
    let retentionAnalysisService: RetentionAnalysisServiceProtocol
    let geoDistributionService: GeoDistributionServiceProtocol
    let aiAnalysisService: AIAnalysisServiceProtocol
}
