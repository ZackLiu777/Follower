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
    /// 总互动事件数
    let totalEvents: Int
    /// 星期分布占比（7 个，索引 0=Sun...6=Sat，最大值为 1.0）
    let dayDistribution: [Double]
    /// 时段分布占比（4 个：凌晨 0-5 / 上午 6-11 / 下午 12-17 / 晚上 18-23，最大值为 1.0）
    let periodDistribution: [Double]

    /// 查询指定 (weekday, hour) 的密度
    func density(weekday: Int, hour: Int) -> Double {
        cells.first(where: { $0.weekday == weekday && $0.hour == hour })?.density ?? 0
    }
}

// MARK: - EngagementHeatmapServiceProtocol

protocol EngagementHeatmapServiceProtocol: Sendable {
    /// 基于 Event 加权 + Snapshot 互动增量生成 7×24 互动热力图
    func generate(from events: [Event], snapshots: [Snapshot]) async -> EngagementHeatmapResult
}

// MARK: - EngagementHeatmapService

/// 互动热力图服务：统计互动密度在各 (weekday, hour) 的分布。
///
/// 双通道合成（v0.16-alpha，替代纯事件计数）：
/// - 通道 1（事件加权）：真互动事件权重 1.0，followerChange 弱信号 0.3，
///   profileSnapshot 不重复计数（互动已由通道 2 覆盖）。
/// - 通道 2（快照互动增量）：相邻快照 likes+comments+shares 的环比增长，
///   归一化到 0-1 后归入快照时间戳所在 (weekday, hour) —— 真实互动指标，
///   避免热力图被「同步节奏」事件主导。
final class EngagementHeatmapService: EngagementHeatmapServiceProtocol {

    private let calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 1  // Sunday = 1
        return c
    }()

    /// 事件类型 → 互动权重（确定性纯函数，便于测试）：
    /// 真互动事件权重最高；followerChange 弱信号；profileSnapshot 由快照增量通道覆盖
    static func eventWeight(for type: EventType) -> Double {
        switch type {
        case .postInteraction, .storyView, .engagementUpdate: return 1.0
        case .followerChange: return 0.3
        case .profileSnapshot: return 0
        }
    }

    func generate(from events: [Event], snapshots: [Snapshot]) async -> EngagementHeatmapResult {
        guard !events.isEmpty || !snapshots.isEmpty else {
            return emptyResult()
        }

        // 加权计数 [weekday: [hour: weightedCount]]
        var counts: [Int: [Int: Double]] = [:]
        var maxCount = 1.0

        func add(_ wd: Int, _ hr: Int, _ weight: Double) {
            guard weight > 0 else { return }
            var hourMap = counts[wd] ?? [:]
            let newCount = (hourMap[hr] ?? 0) + weight
            hourMap[hr] = newCount
            counts[wd] = hourMap
            if newCount > maxCount { maxCount = newCount }
        }

        // 通道 1：事件加权计数
        for event in events {
            let wd = calendar.component(.weekday, from: event.observedAt)
            let hr = calendar.component(.hour, from: event.observedAt)
            add(wd, hr, Self.eventWeight(for: event.eventType))
        }

        // 通道 2：快照互动增量（likes+comments+shares 环比增长 → 该时段新增互动）
        var deltas: [(wd: Int, hr: Int, value: Double)] = []
        var deltaMax = 1.0
        var prevEngagement: Int?
        for snapshot in snapshots.sorted(by: { $0.observedAt < $1.observedAt }) {
            let engagement = snapshot.totalLikes + snapshot.totalComments + snapshot.totalShares
            if let prev = prevEngagement {
                let delta = Double(max(engagement - prev, 0))
                if delta > 0 {
                    let wd = calendar.component(.weekday, from: snapshot.observedAt)
                    let hr = calendar.component(.hour, from: snapshot.observedAt)
                    deltas.append((wd, hr, delta))
                    if delta > deltaMax { deltaMax = delta }
                }
            }
            prevEngagement = engagement
        }
        // 归一化到 0-1，与事件通道同量级
        for d in deltas {
            add(d.wd, d.hr, d.value / deltaMax)
        }

        // 转换为 density (0-1)
        var cells: [HeatmapCell] = []
        var bestDensity: Double = 0
        var bestDay = 0
        var bestHour = 0

        // 星期计数（索引 0=Sun...6=Sat）与时段计数（凌晨 0-5 / 上午 6-11 / 下午 12-17 / 晚上 18-23）
        var dayCounts = [Double](repeating: 0, count: 7)
        var periodCounts = [Double](repeating: 0, count: 4)

        for wd in 1...7 {
            let hourMap = counts[wd] ?? [:]
            for hr in 0..<24 {
                let count = hourMap[hr] ?? 0
                let density = count / maxCount
                let cell = HeatmapCell(weekday: wd, hour: hr, density: density)
                cells.append(cell)

                dayCounts[wd - 1] += count
                periodCounts[hr / 6] += count

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

        // 归一化分布占比：各自最大值映射为 1.0，保持相对比例
        func normalized(_ counts: [Double]) -> [Double] {
            let peak = counts.max() ?? 1
            return counts.map { $0 / max(peak, 1) }
        }

        return EngagementHeatmapResult(
            cells: cells,
            bestDay: bestDay,
            bestHour: bestHour,
            peakDescription: peakDesc,
            totalEvents: events.count,
            dayDistribution: normalized(dayCounts),
            periodDistribution: normalized(periodCounts)
        )
    }

    private func emptyResult() -> EngagementHeatmapResult {
        EngagementHeatmapResult(
            cells: [],
            bestDay: 0,
            bestHour: 0,
            peakDescription: "No data",
            totalEvents: 0,
            dayDistribution: [Double](repeating: 0, count: 7),
            periodDistribution: [Double](repeating: 0, count: 4)
        )
    }
}
