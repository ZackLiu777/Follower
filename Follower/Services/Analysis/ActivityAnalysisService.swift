//
//  ActivityAnalysisService.swift
//  Follower
//
//  Gamma: 活跃度分析（Premium）。基于 Event 时间分布。

import Foundation

struct ActivityResult: Sendable {
    let activeDaysRatio: Double        // 0-1，有数据的天数占比
    let mostActiveDay: Int?            // 1=Sun...7=Sat
    let avgEventsPerActiveDay: Double
    let totalDays: Int
    let activeDays: Int
    let label: String                  // "Highly Active" / "Active" / "Moderate" / "Low"
}

protocol ActivityAnalysisServiceProtocol: Sendable {
    func analyze(events: [Event], from: Date, to: Date) async -> ActivityResult
}

final class ActivityAnalysisService: ActivityAnalysisServiceProtocol {
    private let calendar = Calendar.current

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
