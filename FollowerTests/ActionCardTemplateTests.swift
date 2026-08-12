//
//  ActionCardTemplateTests.swift
//  FollowerTests
//
//  ActionCard 模板渲染单元测试 — displayTitle / displayActions /
//  displayReason / displayImpact 各分支与边界（day 越界 clamp）。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for ActionCardTemplate — branch rendering, boundary clamping
struct ActionCardTemplateTests {

    // MARK: - displayTitle 分支

    /// primary 卡片：growing / declining / stable / severe 四上下文标题互不相同
    @Test
    func testPrimaryTitleDiffersByContext() {
        let growing = ActionCardTemplate.primary(contentType: .reel, outperformanceX: 2.0, context: .growing)
        let declining = ActionCardTemplate.primary(contentType: .reel, outperformanceX: 2.0, context: .declining)
        let stable = ActionCardTemplate.primary(contentType: .reel, outperformanceX: 2.0, context: .stable)
        let severe = ActionCardTemplate.primary(contentType: .reel, outperformanceX: 2.0, context: .severe)

        #expect(!growing.displayTitle.isEmpty)
        #expect(growing.displayTitle != declining.displayTitle)
        #expect(growing.displayTitle != stable.displayTitle)
        // severe 与 declining 共用 reverse 标题
        #expect(severe.displayTitle == declining.displayTitle)
    }

    /// alert 卡片：penalty > 0.3 → 严重标题；≤ 0.3 → 轻微标题
    @Test
    func testAlertTitleByPenaltyThreshold() {
        let severe = ActionCardTemplate.alert(fatiguedType: .carousel, penalty: 0.5)
        let mild = ActionCardTemplate.alert(fatiguedType: .carousel, penalty: 0.3)
        #expect(severe.displayTitle != mild.displayTitle)
        #expect(!severe.displayTitle.isEmpty)
    }

    /// recovery 卡片：severe 上下文 → 关键标题；其余 → 中度标题
    @Test
    func testRecoveryTitleByContext() {
        let critical = ActionCardTemplate.recovery(inactivePct: 80, context: .severe)
        let moderate = ActionCardTemplate.recovery(inactivePct: 80, context: .declining)
        #expect(critical.displayTitle != moderate.displayTitle)
    }

    /// insight 卡片：variation 0/1/2/3 四分支（0 默认 = 最佳发帖时间）
    @Test
    func testInsightTitleVariations() {
        let base = ActionCardTemplate.insight(bestDay: 4, bestHour: "19:00", variation: 0)
        let content = ActionCardTemplate.insight(bestDay: 4, bestHour: "19:00", variation: 1)
        let engagement = ActionCardTemplate.insight(bestDay: 4, bestHour: "19:00", variation: 2)
        let growth = ActionCardTemplate.insight(bestDay: 4, bestHour: "19:00", variation: 3)

        #expect(!base.displayTitle.isEmpty)
        #expect(content.displayTitle != base.displayTitle)
        #expect(engagement.displayTitle != base.displayTitle)
        #expect(growth.displayTitle != base.displayTitle)
    }

    // MARK: - displayActions 分支

    /// primary growing → 2 条建议；declining → 3 条
    @Test
    func testPrimaryActionCountByContext() {
        let growing = ActionCardTemplate.primary(contentType: .reel, outperformanceX: 2.0, context: .growing)
        let declining = ActionCardTemplate.primary(contentType: .reel, outperformanceX: 2.0, context: .declining)
        #expect(growing.displayActions.count == 2)
        #expect(declining.displayActions.count == 3)
    }

    /// alert 卡片：severe → 2 条（停更+转型）；mild → 1 条（减少发帖）
    @Test
    func testAlertActionCountByPenalty() {
        let severe = ActionCardTemplate.alert(fatiguedType: .carousel, penalty: 0.5)
        let mild = ActionCardTemplate.alert(fatiguedType: .carousel, penalty: 0.3)
        #expect(severe.displayActions.count == 2)
        #expect(mild.displayActions.count == 1)
    }

    /// recovery 卡片：severe → 3 条；moderate → 2 条
    @Test
    func testRecoveryActionCountByContext() {
        let critical = ActionCardTemplate.recovery(inactivePct: 62, context: .severe)
        let moderate = ActionCardTemplate.recovery(inactivePct: 62, context: .stable)
        #expect(critical.displayActions.count == 3)
        #expect(moderate.displayActions.count == 2)
    }

    /// insight 卡片 → 1 条建议，包含星期名与时段
    @Test
    func testInsightActionContainsSchedule() {
        let insight = ActionCardTemplate.insight(bestDay: 4, bestHour: "19:00", variation: 0)
        let action = insight.displayActions
        #expect(action.count == 1)
        #expect(action[0].contains("19:00"))
    }

    // MARK: - displayReason / displayImpact

    /// displayReason 各类型非空；alert 严重/轻微原因不同
    @Test
    func testDisplayReasonNonEmptyAndDistinct() {
        let severeAlert = ActionCardTemplate.alert(fatiguedType: .reel, penalty: 0.5)
        let mildAlert = ActionCardTemplate.alert(fatiguedType: .reel, penalty: 0.3)
        #expect(!severeAlert.displayReason.isEmpty)
        #expect(severeAlert.displayReason != mildAlert.displayReason)

        let primary = ActionCardTemplate.primary(contentType: .reel, outperformanceX: 2.0, context: .growing)
        #expect(!primary.displayReason.isEmpty)
    }

    /// displayImpact：alert 为 nil；primary/insight 非 nil
    @Test
    func testDisplayImpactNullability() {
        let alert = ActionCardTemplate.alert(fatiguedType: .reel, penalty: 0.3)
        #expect(alert.displayImpact == nil)

        let primary = ActionCardTemplate.primary(contentType: .reel, outperformanceX: 2.0, context: .growing)
        #expect(primary.displayImpact != nil)

        let insight = ActionCardTemplate.insight(bestDay: 4, bestHour: "19:00", variation: 0)
        #expect(insight.displayImpact != nil)
    }

    // MARK: - day 边界（clamp 防护）

    /// insight bestDay 越界（0 / 8）→ 不崩溃，星期名落在合法范围
    @Test
    func testInsightDayOutOfRangeDoesNotCrash() {
        let dayZero = ActionCardTemplate.insight(bestDay: 0, bestHour: "19:00", variation: 0)
        let dayEight = ActionCardTemplate.insight(bestDay: 8, bestHour: "19:00", variation: 0)
        #expect(!dayZero.displayTitle.isEmpty)
        #expect(!dayEight.displayTitle.isEmpty)
        #expect(!dayZero.displayReason.isEmpty)
        #expect(!dayEight.displayReason.isEmpty)
    }

    /// bestDay 1 与 7 是不同星期 → 建议文案不同
    @Test
    func testInsightDayOneAndSevenDiffer() {
        let monday = ActionCardTemplate.insight(bestDay: 1, bestHour: "19:00", variation: 0)
        let sunday = ActionCardTemplate.insight(bestDay: 7, bestHour: "19:00", variation: 0)
        #expect(monday.displayReason != sunday.displayReason)
    }

    // MARK: - sampleCards

    /// 示例卡片：4 张、4 种类型、priority 升序
    @Test
    func testSampleCardsCoverAllTypesSorted() {
        let cards = ActionCard.sampleCards
        #expect(cards.count == 4)
        #expect(Set(cards.map(\.type)) == Set(CardType.allCases))
        for i in 0..<(cards.count - 1) {
            #expect(cards[i].priority < cards[i + 1].priority)
        }
    }
}
