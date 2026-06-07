//
//  GeoDistributionService.swift
//  Follower
//
//  Gamma: 地域分布（Premium）。Mock 数据，预留真实 API 接口。

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

    /// Mock 数据：全球主要地区分布（基于公开的 Instagram 用户统计趋势）
    func fetchDistribution(accountId _: Int64) async -> GeoDistributionResult {
        let mockRegions = [
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
        return GeoDistributionResult(regions: mockRegions, totalRegions: mockRegions.count, topRegion: mockRegions.first)
    }
}
