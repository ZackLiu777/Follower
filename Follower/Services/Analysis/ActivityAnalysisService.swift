//
//  ActivityAnalysisService.swift
//  Follower
//
//  Gamma: 活跃度分析（Premium）。基于 Event 时间分布。

import Foundation

/// 活跃度分析结果：活跃天数比例、最活跃星期、事件密度等
struct ActivityResult: Sendable {
    let activeDaysRatio: Double        // 0-1，有数据的天数占比
    let mostActiveDay: Int?            // 1=Sun...7=Sat
    let avgEventsPerActiveDay: Double
    let totalDays: Int
    let activeDays: Int
    let label: String                  // "Highly Active" / "Active" / "Moderate" / "Low"
}

/// 活跃度分析服务协议（Premium）
protocol ActivityAnalysisServiceProtocol: Sendable {
    /// 分析事件的时间分布，返回活跃度指标
    func analyze(events: [Event], from: Date, to: Date) async -> ActivityResult
}

/// 活跃度分析服务实现：按天统计 Event 分布 + 星期分布 + 活跃级别标签
final class ActivityAnalysisService: ActivityAnalysisServiceProtocol {
    private let calendar = Calendar.current

    /// 统计 Event 在时间范围内的分布：活跃天比例 / 最活跃星期 / 日均事件数
    func analyze(events: [Event], from: Date, to: Date) async -> ActivityResult {
        let totalDays = max(1, calendar.dateComponents([.day], from: from, to: to).day ?? 1)

        let groupedByDay = Dictionary(grouping: events) { calendar.startOfDay(for: $0.observedAt) }
        let activeDays = groupedByDay.count
        let activeDaysRatio = Double(activeDays) / Double(totalDays)

        var weekdayCount: [Int: Int] = [:]
        for event in events {
            let wd = calendar.component(.weekday, from: event.observedAt)
            weekdayCount[wd, default: 0] += 1
        }
        let mostActiveDay = weekdayCount.max(by: { $0.value < $1.value })?.key
        let avgEvents = activeDays > 0 ? Double(events.count) / Double(activeDays) : 0

        let label: String
        switch activeDaysRatio {
        case 0.8...1.0: label = "Highly Active"
        case 0.5..<0.8: label = "Active"
        case 0.2..<0.5: label = "Moderate"
        default:        label = "Low"
        }

        return ActivityResult(
            activeDaysRatio: activeDaysRatio,
            mostActiveDay: mostActiveDay,
            avgEventsPerActiveDay: avgEvents,
            totalDays: totalDays,
            activeDays: activeDays,
            label: label
        )
    }
}
