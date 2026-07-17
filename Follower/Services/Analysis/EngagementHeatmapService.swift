//
//  EngagementHeatmapService.swift
//  Follower
//
//  Phi: 互动热力图服务（Premium）。
//  基于 Event 时间戳分析每周各天 + 每小时段的互动密度。
//

import Foundation

// MARK: - HeatmapCell

/// 热力图单个单元格数据
struct HeatmapCell: Sendable {
    /// 星期几 1=Sun ... 7=Sat (Calendar weekday)
    let weekday: Int
    /// 小时 0-23
    let hour: Int
    /// 互动密度 0.0-1.0
    let density: Double
}

// MARK: - EngagementHeatmapResult

/// 互动热力图结果
struct EngagementHeatmapResult: Sendable {
    /// 7×24 网格数据
    let cells: [HeatmapCell]
    /// 最佳互动日
    let bestDay: Int
    /// 最佳互动小时
    let bestHour: Int
    /// 最佳时段描述（如 "Wed 19:00"）
    let peakDescription: String

    /// 查询指定 (weekday, hour) 的密度
    func density(weekday: Int, hour: Int) -> Double {
        cells.first(where: { $0.weekday == weekday && $0.hour == hour })?.density ?? 0
    }
}

// MARK: - EngagementHeatmapServiceProtocol

protocol EngagementHeatmapServiceProtocol: Sendable {
    /// 基于 Event 时间序列生成 7×24 互动热力图
    func generate(from events: [Event]) async -> EngagementHeatmapResult
}

// MARK: - EngagementHeatmapService

/// 互动热力图服务：统计 Event 在各 (weekday, hour) 的分布密度
final class EngagementHeatmapService: EngagementHeatmapServiceProtocol {

    private let calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 1  // Sunday = 1
        return c
    }()

    func generate(from events: [Event]) async -> EngagementHeatmapResult {
        guard !events.isEmpty else {
            return emptyResult()
        }

        // 统计每个 (weekday, hour) 的事件数
        var counts: [Int: [Int: Int]] = [:]  // [weekday: [hour: count]]
        var maxCount = 1

        for event in events {
            let wd = calendar.component(.weekday, from: event.observedAt)
            let hr = calendar.component(.hour, from: event.observedAt)

            var hourMap = counts[wd] ?? [:]
            let newCount = (hourMap[hr] ?? 0) + 1
            hourMap[hr] = newCount
            counts[wd] = hourMap
            if newCount > maxCount { maxCount = newCount }
        }

        // 转换为 density (0-1)
        var cells: [HeatmapCell] = []
        var bestDensity: Double = 0
        var bestDay = 0
        var bestHour = 0

        for wd in 1...7 {
            let hourMap = counts[wd] ?? [:]
            for hr in 0..<24 {
                let count = hourMap[hr] ?? 0
                let density = Double(count) / Double(maxCount)
                let cell = HeatmapCell(weekday: wd, hour: hr, density: density)
                cells.append(cell)

                if density > bestDensity {
                    bestDensity = density
                    bestDay = wd
                    bestHour = hr
                }
            }
        }

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let dayName = bestDay >= 1 && bestDay <= 7 ? dayNames[bestDay - 1] : "?"
        let peakDesc = "\(dayName) \(String(format: "%02d:00", bestHour))"

        return EngagementHeatmapResult(
            cells: cells,
            bestDay: bestDay,
            bestHour: bestHour,
            peakDescription: peakDesc
        )
    }

    private func emptyResult() -> EngagementHeatmapResult {
        EngagementHeatmapResult(
            cells: [],
            bestDay: 0,
            bestHour: 0,
            peakDescription: "No data"
        )
    }
}
