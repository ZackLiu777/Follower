//
//  ActionCard.swift
//  Follower
//
//  Growth Decision Engine 的输出单元 — 定义行动卡片类型、结构与示例数据。

import Foundation

// MARK: - CardType

/// 行动卡片类型：主行动 / 疲劳提醒 / 恢复建议 / 通用洞察
enum CardType: String, Sendable, CaseIterable {
    /// 🔥 今日主行动 — 最高优先级的增长操作
    case primary
    /// ⚠️ 疲劳/异常提醒 — 内容或互动指标恶化
    case alert
    /// ⚡ 恢复增长建议 — 粉丝重新激活
    case recovery
    /// 💡 通用洞察 — 最佳时间等辅助信息
    case insight
}

// MARK: - ActionCard

/// 行动卡片 — Growth Decision Engine 的输出单元
/// 由 CardGenerator 根据 GrowthScores 生成，最终渲染在 DecisionsView 中
struct ActionCard: Identifiable, Sendable {
    /// 唯一标识符（UUID）
    let id: String
    /// 卡片类型，决定视觉优先级和图标风格
    let type: CardType
    /// SF Symbol 图标名称
    let icon: String
    /// 卡片标题（纯大写英文，保持视觉一致性）
    let title: String
    /// 建议的具体行动列表（按执行顺序排列）
    let actions: [String]
    /// 推荐原因说明
    let reason: String
    /// 预期效果描述（nullable，alert 类型通常为 nil）
    let impact: String?
    /// 排序优先级，越小越靠前
    let priority: Int
}

// MARK: - Sample Data (Preview)

extension ActionCard {
    /// 示例卡片数组，供 Preview 和 UI 开发使用
    static let sampleCards: [ActionCard] = [
        ActionCard(
            id: "1",
            type: .primary,
            icon: "flame.fill",
            title: "BOOST GROWTH TODAY",
            actions: [
                "Post 1 Reel (highest ROI format)",
                "Engage 5 high-value followers",
                "Reply to top comments"
            ],
            reason: "Reels outperform other formats by 2.3x",
            impact: "+80 ~ +150 followers",
            priority: 0
        ),
        ActionCard(
            id: "2",
            type: .alert,
            icon: "exclamationmark.triangle.fill",
            title: "CONTENT FATIGUE",
            actions: [
                "Reduce carousel posts this week"
            ],
            reason: "Carousel performance ↓28% — posting frequency too high",
            impact: nil,
            priority: 1
        ),
        ActionCard(
            id: "3",
            type: .recovery,
            icon: "arrow.up.heart.fill",
            title: "ENGAGEMENT RECOVERY",
            actions: [
                "DM 3 active supporters",
                "Re-engage top commenters"
            ],
            reason: "62% followers inactive — re-engagement needed",
            impact: "+30 ~ +50 re-engaged followers",
            priority: 2
        ),
        ActionCard(
            id: "4",
            type: .insight,
            icon: "lightbulb.fill",
            title: "BEST POSTING TIME",
            actions: [
                "Schedule posts for Wednesday 7 PM"
            ],
            reason: "Your audience is most active Wed 19:00–21:00",
            impact: "+15% engagement",
            priority: 3
        )
    ]
}
