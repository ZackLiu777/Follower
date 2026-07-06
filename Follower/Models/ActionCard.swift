//
//  ActionCard.swift
//  Follower
//
//  Growth Decision Engine — 数据驱动模板 + 上下文感知渲染。
//  卡片建议随 score / growth / fatigue 的实际值动态变化。
//

import Foundation

// MARK: - CardType

enum CardType: String, Sendable, CaseIterable {
    case primary, alert, recovery, insight
}

// MARK: - CardContext (数据上下文 — 驱动文案变化)

/// 数据上下文 — 决定卡片文案的语气和建议方向
enum CardContext: String, Sendable {
    case growing      // 数据向好 → 加速/保持
    case declining    // 数据下滑 → 反转/干预
    case stable       // 数据平稳 → 优化/微调
    case severe       // 严重问题 → 紧急行动
}

// MARK: - ActionCardTemplate

/// 卡片模板 — 存储计算参数 + 数据上下文，View 层据此生成本地化文案
enum ActionCardTemplate: Sendable {
    case primary(contentType: ContentType, outperformanceX: Double, context: CardContext)
    case alert(fatiguedType: ContentType, penalty: Double)
    case recovery(inactivePct: Int, context: CardContext)
    case insight(bestDay: Int, bestHour: String)
}

// MARK: - ActionCard

struct ActionCard: Identifiable, Sendable {
    let id: String
    let type: CardType
    let icon: String
    let template: ActionCardTemplate
    let priority: Int
}

// MARK: - Localized Rendering

extension ActionCardTemplate {

    var displayTitle: String {
        switch self {
        case .primary(_, _, let ctx):
            switch ctx {
            case .growing:   return loc(L10n.Decisions.primaryBoostTitle)
            case .declining: return loc(L10n.Decisions.primaryReverseTitle)
            case .stable:    return loc(L10n.Decisions.primarySustainTitle)
            case .severe:    return loc(L10n.Decisions.primaryReverseTitle)
            }
        case .alert(_, let penalty):
            return penalty > 0.3
                ? loc(L10n.Decisions.alertSevereTitle)
                : loc(L10n.Decisions.alertMildTitle)
        case .recovery(_, let ctx):
            return ctx == .severe
                ? loc(L10n.Decisions.recoveryCriticalTitle)
                : loc(L10n.Decisions.recoveryModerateTitle)
        case .insight:
            return loc(L10n.Decisions.bestPostingTime)
        }
    }

    var displayActions: [String] {
        switch self {
        case .primary(let type, let x, let ctx):
            let name = "\(type)".capitalized
            switch ctx {
            case .growing:
                return [
                    String(format: loc(L10n.Decisions.actionDoubleDown), name, String(format: "%.1f", x)),
                    loc(L10n.Decisions.actionEngageTopFans)
                ]
            case .declining:
                return [
                    String(format: loc(L10n.Decisions.actionTryFormat), name),
                    loc(L10n.Decisions.actionReplyAll),
                    loc(L10n.Decisions.actionCrossPromote)
                ]
            case .stable:
                return [
                    String(format: loc(L10n.Decisions.actionOptimizeTiming), name),
                    loc(L10n.Decisions.actionTestVariation)
                ]
            case .severe:
                return [
                    String(format: loc(L10n.Decisions.actionTryFormat), name),
                    loc(L10n.Decisions.actionEngageTopFans),
                    loc(L10n.Decisions.actionReplyAll)
                ]
            }
        case .alert(let type, let p):
            let name = "\(type)".capitalized
            return p > 0.3
                ? [String(format: loc(L10n.Decisions.actionStopType), name),
                   String(format: loc(L10n.Decisions.actionDiversifyFrom), name)]
                : [String(format: loc(L10n.Decisions.actionReducePosts), name)]
        case .recovery(let pct, let ctx):
            let n = max(3, Int(Double(pct) / 20.0))
            return ctx == .severe
                ? [String(format: loc(L10n.Decisions.actionDMFollowers), n),
                   loc(L10n.Decisions.actionRunGiveaway),
                   loc(L10n.Decisions.actionAskEngagement)]
                : [loc(L10n.Decisions.actionDMSupporters),
                   loc(L10n.Decisions.actionReengage)]
        case .insight(let day, let hour):
            let dayName = dayNames[clamp(day - 1, 0, 6)]
            return [String(format: loc(L10n.Decisions.actionSchedule), dayName, hour)]
        }
    }

    var displayReason: String {
        switch self {
        case .primary(let type, let x, let ctx):
            let name = "\(type)".capitalized
            switch ctx {
            case .growing:
                return String(format: loc(L10n.Decisions.reasonMomentum), name, String(format: "%.1f", x))
            case .declining:
                return String(format: loc(L10n.Decisions.reasonDeclining), name, String(format: "%.1f", x))
            case .stable, .severe:
                return String(format: loc(L10n.Decisions.reasonReelOutperform), name, String(format: "%.1f", x))
            }
        case .alert(let type, let p):
            let name = "\(type)".capitalized
            return p > 0.3
                ? String(format: loc(L10n.Decisions.reasonFatigueSevere), name)
                : String(format: loc(L10n.Decisions.reasonPerformanceDeclining), name)
        case .recovery(let pct, let ctx):
            return ctx == .severe
                ? String(format: loc(L10n.Decisions.reasonCriticalInactive), pct)
                : String(format: loc(L10n.Decisions.reasonInactiveFollowers), pct)
        case .insight(let day, let hour):
            let dayName = dayNames[clamp(day - 1, 0, 6)]
            return String(format: loc(L10n.Decisions.reasonAudienceActive), dayName, hour)
        }
    }

    var displayImpact: String? {
        switch self {
        case .primary(_, _, let ctx):
            switch ctx {
            case .growing:   return loc(L10n.Decisions.impactBoost)
            case .declining: return loc(L10n.Decisions.impactReverse)
            case .stable:    return loc(L10n.Decisions.impactOptimize)
            case .severe:    return loc(L10n.Decisions.impactReverse)
            }
        case .alert: return nil
        case .recovery(_, let ctx):
            return ctx == .severe
                ? loc(L10n.Decisions.impactCritical)
                : loc(L10n.Decisions.impactRecovery)
        case .insight: return loc(L10n.Decisions.impactEngagement)
        }
    }
}

// MARK: - Helpers

private let dayNames = [
    loc(L10n.Premium.daySun), loc(L10n.Premium.dayMon), loc(L10n.Premium.dayTue),
    loc(L10n.Premium.dayWed), loc(L10n.Premium.dayThu), loc(L10n.Premium.dayFri),
    loc(L10n.Premium.daySat)
]

private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { Swift.min(hi, Swift.max(lo, v)) }

// MARK: - Sample Data

extension ActionCard {
    static let sampleCards: [ActionCard] = [
        ActionCard(id: "1", type: .primary, icon: "flame.fill",
            template: .primary(contentType: .reel, outperformanceX: 2.3, context: .growing), priority: 0),
        ActionCard(id: "2", type: .alert, icon: "exclamationmark.triangle.fill",
            template: .alert(fatiguedType: .carousel, penalty: 0.3), priority: 1),
        ActionCard(id: "3", type: .recovery, icon: "arrow.up.heart.fill",
            template: .recovery(inactivePct: 62, context: .severe), priority: 2),
        ActionCard(id: "4", type: .insight, icon: "lightbulb.fill",
            template: .insight(bestDay: 4, bestHour: "19:00"), priority: 3)
    ]
}
