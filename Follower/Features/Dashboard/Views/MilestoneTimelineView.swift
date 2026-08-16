//
//  MilestoneTimelineView.swift
//  Follower
//
//  Premium: 成长里程碑（Phi+）— 事件叙事时间线。
//  ① 摘要卡：事件总数 / 爆帖数 / 最佳单帖互动
//  ② 时间线：粉丝里程碑 / 爆帖 / 最佳单帖 / 掉粉事件 / 最佳一周（最近在上）
//  全部 theme 化；无事件 → 空态。
//

import SwiftUI

/// 成长里程碑详情页
struct MilestoneTimelineView: View {
    @Environment(\.theme) private var theme

    let result: MilestoneResult?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if let result, !result.events.isEmpty {
                        summaryCard(result)
                        timelineCard(result.events)
                        if let latest = result.latest {
                            latestCard(latest)
                        }
                    } else {
                        ContentUnavailableView(
                            loc(L10n.Premium.milestoneNoData),
                            systemImage: "flag.checkered",
                            description: Text(loc(L10n.Premium.milestoneNoDataDesc))
                        )
                        .padding(.top, 80)
                    }
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.milestones))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 摘要卡

    private func summaryCard(_ result: MilestoneResult) -> some View {
        HStack(spacing: 12) {
            summaryStat(value: "\(result.totalEvents)", label: loc(L10n.Premium.milestoneSummaryEvents))
            summaryStat(value: "\(result.viralCount)", label: loc(L10n.Premium.milestoneSummaryViral))
            summaryStat(
                value: result.bestPost.map { Self.formatValue($0.value) } ?? "—",
                label: loc(L10n.Premium.milestoneSummaryBest)
            )
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(theme.accentPrimary)
            Text(label)
                .font(.caption).foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 时间线

    private func timelineCard(_ events: [MilestoneEvent]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(events.reversed().enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 12) {
                    // 时间线圆点 + 连线
                    VStack(spacing: 0) {
                        Image(systemName: Self.icon(for: event.kind))
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Self.color(for: event.kind)))
                        if index < events.count - 1 {
                            Rectangle()
                                .fill(theme.textSecondary.opacity(0.15))
                                .frame(width: 2, height: 14)
                        }
                    }
                    .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title(for: event))
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(theme.textPrimary)
                        Text(dayLabel(event.date))
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 2)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - 最近事件

    private func latestCard(_ event: MilestoneEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundColor(theme.accentPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(loc(L10n.Premium.milestoneLastEvent))
                    .font(.caption2).foregroundColor(theme.textSecondary)
                Text(title(for: event))
                    .font(.footnote).fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
            }
            Spacer()
            Text(dayLabel(event.date))
                .font(.caption).foregroundColor(theme.textSecondary)
        }
        .padding()
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - 渲染辅助

    private func title(for event: MilestoneEvent) -> String {
        let value = Self.formatValue(event.value)
        switch event.kind {
        case .followerMilestone:
            return String(format: loc(L10n.Premium.milestoneFollower), value)
        case .viralPost:
            return String(format: loc(L10n.Premium.milestoneViral), value)
        case .bestPost:
            return String(format: loc(L10n.Premium.milestoneBest), value)
        case .unfollowEvent:
            return String(format: loc(L10n.Premium.milestoneUnfollow), value)
        case .boostWeek:
            return String(format: loc(L10n.Premium.milestoneBoostWeek), value)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return loc(L10n.Premium.milestoneToday)
        }
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }

    static func icon(for kind: MilestoneKind) -> String {
        switch kind {
        case .followerMilestone: return "flag.checkered"
        case .viralPost: return "flame.fill"
        case .bestPost: return "trophy.fill"
        case .unfollowEvent: return "arrow.down.circle.fill"
        case .boostWeek: return "chart.line.uptrend.xyaxis"
        }
    }

    static func color(for kind: MilestoneKind) -> Color {
        switch kind {
        case .followerMilestone: return .blue
        case .viralPost: return .orange
        case .bestPost: return .yellow
        case .unfollowEvent: return .red
        case .boostWeek: return .green
        }
    }

    /// 数值缩写：1.2K / 3.4M；< 1000 原样
    static func formatValue(_ value: Int) -> String {
        let absValue = abs(Double(value))
        if absValue >= 1_000_000 {
            return String(format: "%.1fM", absValue / 1_000_000)
        }
        if absValue >= 1_000 {
            return String(format: "%.1fK", absValue / 1_000)
        }
        return "\(value)"
    }
}

// MARK: - Previews

#Preview("数据") {
    NavigationStack {
        MilestoneTimelineView(result: MilestoneResult(
            events: [
                MilestoneEvent(kind: .followerMilestone, date: Date().addingTimeInterval(-86400 * 30), value: 10_000, secondaryValue: 10_240),
                MilestoneEvent(kind: .viralPost, date: Date().addingTimeInterval(-86400 * 12), value: 1_240, secondaryValue: 0),
                MilestoneEvent(kind: .bestPost, date: Date().addingTimeInterval(-86400 * 8), value: 3_180, secondaryValue: 0),
                MilestoneEvent(kind: .unfollowEvent, date: Date().addingTimeInterval(-86400 * 3), value: 42, secondaryValue: 0),
                MilestoneEvent(kind: .boostWeek, date: Date().addingTimeInterval(-86400 * 1), value: 320, secondaryValue: 7),
            ],
            bestPost: MilestoneEvent(kind: .bestPost, date: Date().addingTimeInterval(-86400 * 8), value: 3_180, secondaryValue: 0)
        ))
    }
}

#Preview("空态") {
    NavigationStack {
        MilestoneTimelineView(result: nil)
    }
}
