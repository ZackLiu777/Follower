//
//  DecisionTemplateTests.swift
//  FollowerTests
//
//  DecisionTemplate 模板渲染单元测试 — displayTitle / displayActions /
//  displayReason 参数化格式化、impactText、formatCount、sampleCards。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for DecisionTemplate — 参数化渲染与量化收益
struct DecisionTemplateTests {

    /// 构造模板（使用带 %@ 占位符的 Tpl 模板 key）
    private func makeTemplate(
        titleArgs: [String] = ["Reel"],
        reasonArgs: [String] = ["Reel", "2"],
        actionArgs: [[String]] = [["2", "Reel"]]
    ) -> DecisionTemplate {
        DecisionTemplate(
            id: "test.template", type: .content, icon: "flame.fill",
            titleKey: Tpl.Title.boostTopType, titleArgs: titleArgs,
            reasonKey: Tpl.Reason.perPostGain, reasonArgs: reasonArgs,
            actionKeys: [Tpl.Action.boost], actionArgsList: actionArgs
        )
    }

    // MARK: - 参数化渲染

    /// 标题含参数 → 参数被替换
    @Test
    func testDisplayTitleFormatsArgs() {
        let t = makeTemplate(titleArgs: ["Reel"])
        #expect(!t.displayTitle.isEmpty)
        #expect(t.displayTitle.contains("Reel"))
    }

    /// 原因含多个参数 → 全部替换
    @Test
    func testDisplayReasonFormatsArgs() {
        let t = makeTemplate(reasonArgs: ["Reel", "2"])
        #expect(t.displayReason.contains("Reel"))
        #expect(t.displayReason.contains("2"))
    }

    /// 行动参数与 key 一一对应
    @Test
    func testDisplayActionsFormatted() {
        let t = makeTemplate(actionArgs: [["2", "Reel"]])
        let actions = t.displayActions
        #expect(actions.count == 1)
        #expect(actions[0].contains("2"))
        #expect(actions[0].contains("Reel"))
    }

    /// 无参数 key → 直接取本地化文案（不崩溃）
    @Test
    func testTemplateNoArgsRenders() {
        let t = DecisionTemplate(
            id: "test.noargs", type: .ops, icon: "calendar",
            titleKey: L10n.Decisions.tagOps,
            reasonKey: L10n.Decisions.tagOps,
            actionKeys: [L10n.Decisions.tagOps]
        )
        #expect(!t.displayTitle.isEmpty)
        #expect(!t.displayReason.isEmpty)
        #expect(t.displayActions == [t.displayTitle])
    }

    /// 行动参数少于 key（缺省）→ 按无参数渲染，不崩溃
    @Test
    func testTemplateMissingActionArgsDoesNotCrash() {
        let t = DecisionTemplate(
            id: "test.missing", type: .health, icon: "exclamationmark.triangle.fill",
            titleKey: L10n.Decisions.alertSevereTitle,
            reasonKey: L10n.Decisions.reasonFatigueSevere, reasonArgs: ["Carousel"],
            actionKeys: [L10n.Decisions.actionReducePosts, L10n.Decisions.actionDiversifyFrom],
            actionArgsList: [["Carousel"]]
        )
        let actions = t.displayActions
        #expect(actions.count == 2)
        #expect(!actions[0].isEmpty)
        #expect(!actions[1].isEmpty)
    }

    // MARK: - CardType 映射

    /// 7 类全部存在且可枚举
    @Test
    func testCardTypeAllCases() {
        #expect(CardType.allCases.count == 7)
        #expect(CardType.allCases.contains(.content))
        #expect(CardType.allCases.contains(.timing))
        #expect(CardType.allCases.contains(.growth))
        #expect(CardType.allCases.contains(.engagement))
        #expect(CardType.allCases.contains(.reach))
        #expect(CardType.allCases.contains(.health))
        #expect(CardType.allCases.contains(.ops))
    }

    // MARK: - impactText

    /// 粉丝 + 浏览 → 双数字组合文案
    @Test
    func testImpactTextFansAndViews() {
        let card = ActionCard(id: "t1",
            template: makeTemplate(), priority: 0,
            impact: CardImpact(followerGain: 69, viewsGain: 1200))
        let text = card.impactText
        #expect(text != nil)
        #expect(text!.contains("+69"))
        #expect(text!.contains("1.2K"))
    }

    /// 仅粉丝 → 单数字文案
    @Test
    func testImpactTextFansOnly() {
        let card = ActionCard(id: "t2",
            template: makeTemplate(), priority: 0,
            impact: CardImpact(followerGain: 69, viewsGain: 0))
        let text = card.impactText
        #expect(text != nil)
        #expect(text!.contains("+69"))
    }

    /// 仅浏览 → 单数字文案
    @Test
    func testImpactTextViewsOnly() {
        let card = ActionCard(id: "t3",
            template: makeTemplate(), priority: 0,
            impact: CardImpact(followerGain: 0, viewsGain: 890))
        let text = card.impactText
        #expect(text != nil)
        #expect(text!.contains("+890"))
    }

    /// 零收益 → nil（UI 不显示收益徽章）
    @Test
    func testImpactTextZeroReturnsNil() {
        let card = ActionCard(id: "t4",
            template: makeTemplate(), priority: 0,
            impact: .zero)
        #expect(card.impactText == nil)
    }

    // MARK: - formatCount

    /// 数字缩写：<1000 原样；≥1000 K；≥1M M
    @Test
    func testFormatCountAbbreviation() {
        #expect(ActionCard.formatCount(69) == "69")
        #expect(ActionCard.formatCount(999) == "999")
        #expect(ActionCard.formatCount(1000) == "1K")
        #expect(ActionCard.formatCount(1250) == "1.2K")
        #expect(ActionCard.formatCount(2_300_000) == "2.3M")
    }

    // MARK: - sampleCards

    /// 示例卡片：4 张、覆盖不同类别、全部携带量化收益
    @Test
    func testSampleCardsAllQuantified() {
        let cards = ActionCard.sampleCards
        #expect(cards.count == 4)
        #expect(cards.allSatisfy { $0.impact.isQuantified })
        #expect(Set(cards.map(\.type)).count >= 3, "示例应覆盖多个类别")
    }
}
