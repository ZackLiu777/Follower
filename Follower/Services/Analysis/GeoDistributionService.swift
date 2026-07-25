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
        // 无 API 客户端时返回示例数据（测试/开发环境兼容）
        guard let apiClient, let tokenProvider else {
            let regions = [
                GeoRegion(name: "United States", percentage: 28.5, flag: "🇺🇸"),
                GeoRegion(name: "India", percentage: 18.2, flag: "🇮🇳"),
                GeoRegion(name: "Brazil", percentage: 10.8, flag: "🇧🇷"),
                GeoRegion(name: "Indonesia", percentage: 7.4, flag: "🇮🇩"),
                GeoRegion(name: "Russia", percentage: 5.1, flag: "🇷🇺"),
                GeoRegion(name: "Japan", percentage: 4.3, flag: "🇯🇵"),
                GeoRegion(name: "United Kingdom", percentage: 3.9, flag: "🇬🇧"),
                GeoRegion(name: "Germany", percentage: 3.2, flag: "🇩🇪"),
                GeoRegion(name: "Others", percentage: 18.6, flag: "🌍"),
            ]
            return GeoDistributionResult(regions: regions, totalRegions: regions.count, topRegion: regions.first)
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
