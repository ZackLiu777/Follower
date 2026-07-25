//
//  GeoDistributionService.swift
//  Follower
//
//  地域分布（Premium）。通过 Instagram Insights API 获取 audience_country 数据。
//

import Foundation

struct GeoRegion: Sendable, Codable {
    let name: String
    let percentage: Double
    let flag: String
}

struct GeoDistributionResult: Sendable {
    let regions: [GeoRegion]
    let totalRegions: Int
    let topRegion: GeoRegion?
}

protocol GeoDistributionServiceProtocol: Sendable {
    func fetchDistribution(accountId: Int64) async -> GeoDistributionResult
}

final class GeoDistributionService: GeoDistributionServiceProtocol {
    private let apiClient: InstagramAPIClientProtocol?
    private let tokenProvider: TokenProviderProtocol?

    init(apiClient: InstagramAPIClientProtocol? = nil, tokenProvider: TokenProviderProtocol? = nil) {
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
    }

    func fetchDistribution(accountId: Int64) async -> GeoDistributionResult {
        guard let apiClient, let tokenProvider else {
            return GeoDistributionResult(regions: [], totalRegions: 0, topRegion: nil)
        }

        do {
            let token = try await tokenProvider.getToken(accountId: accountId)
            let insights = try await apiClient.fetchInsights(
                accessToken: token,
                metrics: ["audience_country"],
                period: "lifetime"
            )
            // audience_country 返回 breakdown 格式，当前暂不解析
            // 有数据返回即表示 API 可用，后续版本解析具体城市/国家
            if insights.first(where: { $0.name == "audience_country" }) != nil {
                return GeoDistributionResult(regions: [], totalRegions: 0, topRegion: nil)
            }
            return GeoDistributionResult(regions: [], totalRegions: 0, topRegion: nil)
        } catch {
            return GeoDistributionResult(regions: [], totalRegions: 0, topRegion: nil)
        }
    }
}
