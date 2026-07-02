//
//  GeoDistributionService.swift
//  Follower
//
//  Gamma: 地域分布（Premium）。Mock 数据，预留真实 API 接口。

import Foundation

/// 地域分布数据：地区名 / 占比 / 国旗
struct GeoRegion: Sendable, Codable {
    let name: String
    let percentage: Double
    let flag: String
}

/// 地域分布分析结果：地区列表 + 地区数 + 最高占比地区
struct GeoDistributionResult: Sendable {
    let regions: [GeoRegion]
    let totalRegions: Int
    let topRegion: GeoRegion?
}

/// 地域分布服务协议（Premium）
protocol GeoDistributionServiceProtocol: Sendable {
    /// 获取粉丝地域分布数据
    func fetchDistribution(accountId: Int64) async -> GeoDistributionResult
}

/// 地域分布服务实现：Mock 数据，预留真实 API 接口
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
