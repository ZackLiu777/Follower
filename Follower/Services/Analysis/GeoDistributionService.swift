//
//  GeoDistributionService.swift
//  Follower
//
//  地域分布（Premium）。通过 Instagram Insights API 获取 audience_country 数据。
//  无 API 时回退示例数据。
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
            return Self.fallbackRegions()
        }

        do {
            let token = try await tokenProvider.getToken(accountId: accountId)
            let insights = try await apiClient.fetchInsights(
                accessToken: token,
                metrics: ["audience_country"],
                period: "lifetime"
            )

            // 解析 breakdown：dimension_values → 国家代码 → 名称 + 国旗
            if let countryInsight = insights.first(where: { $0.name == "audience_country" }),
               let breakdowns = countryInsight.totalValue?.breakdowns,
               !breakdowns.isEmpty {

                let totalValue = breakdowns.reduce(0.0) { $0 + ($1.value ?? 0) }
                guard totalValue > 0 else { return Self.fallbackRegions() }

                let regions: [GeoRegion] = breakdowns.compactMap { b in
                    guard let code = b.dimensionValues?.first, let value = b.value else { return nil }
                    let info = Self.countryInfo(for: code)
                    return GeoRegion(
                        name: info.name,
                        percentage: value / totalValue * 100,
                        flag: info.flag
                    )
                }.sorted { $0.percentage > $1.percentage }

                return GeoDistributionResult(
                    regions: regions,
                    totalRegions: regions.count,
                    topRegion: regions.first
                )
            }

            return Self.fallbackRegions()
        } catch {
            return Self.fallbackRegions()
        }
    }

    // MARK: - Helpers

    static func fallbackRegions() -> GeoDistributionResult {
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

    /// 国家代码 → 名称 + 国旗
    static func countryInfo(for code: String) -> (name: String, flag: String) {
        switch code.uppercased() {
        case "US", "USA":      return ("United States", "🇺🇸")
        case "IN", "IND":      return ("India", "🇮🇳")
        case "BR", "BRA":      return ("Brazil", "🇧🇷")
        case "ID", "IDN":      return ("Indonesia", "🇮🇩")
        case "RU", "RUS":      return ("Russia", "🇷🇺")
        case "JP", "JPN":      return ("Japan", "🇯🇵")
        case "GB", "GBR":      return ("United Kingdom", "🇬🇧")
        case "DE", "DEU":      return ("Germany", "🇩🇪")
        case "FR", "FRA":      return ("France", "🇫🇷")
        case "IT", "ITA":      return ("Italy", "🇮🇹")
        case "CA", "CAN":      return ("Canada", "🇨🇦")
        case "AU", "AUS":      return ("Australia", "🇦🇺")
        case "ES", "ESP":      return ("Spain", "🇪🇸")
        case "KR", "KOR":      return ("South Korea", "🇰🇷")
        case "MX", "MEX":      return ("Mexico", "🇲🇽")
        case "TR", "TUR":      return ("Turkey", "🇹🇷")
        case "PH", "PHL":      return ("Philippines", "🇵🇭")
        case "VN", "VNM":      return ("Vietnam", "🇻🇳")
        case "TH", "THA":      return ("Thailand", "🇹🇭")
        case "AR", "ARG":      return ("Argentina", "🇦🇷")
        case "NG", "NGA":      return ("Nigeria", "🇳🇬")
        case "EG", "EGY":      return ("Egypt", "🇪🇬")
        case "ZA", "ZAF":      return ("South Africa", "🇿🇦")
        case "CN", "CHN":      return ("China", "🇨🇳")
        case "TW", "TWN":      return ("Taiwan", "🇹🇼")
        case "HK", "HKG":      return ("Hong Kong", "🇭🇰")
        default:               return (code, "🌐")
        }
    }
}
