# Decisions 卡片显示异常 — Bug 排查与修复

> **日期**：2026-07-09 · **模块**：DecisionsView / CardGenerator / ContentView

---

## 1. 现象

Decisions Tab 的卡片数量在运行时不稳定：Preview 中显示 4 张，实际 App 中仅显示 2-3 张，且 `hasAccount` 状态反复在 `false → true → false → true` 之间振荡。

---

## 2. 排查过程

### 2.1 已排除项

| 排查方向 | 结论 |
|---------|------|
| StackView 布局/高度计算 | 4 张卡片均进入 layout，frame 正常 |
| ForEach / card 数据被吞 | `cards.count` 进入 StackView 时已不同 |
| AppState 重复初始化 | 注入路径无误 |
| ViewModel 注入结构 | `@State` 模式正确 |

### 2.2 定位线索

关键 log：
```
[DecisionsView] body render — cards: 0, hasAccount: false, hasData: false
[DecisionsView] body render — cards: 0, hasAccount: true,  hasData: false
[DecisionsView] body render — cards: 0, hasAccount: false, hasData: false  ← hasAccount 振荡
[DecisionsVM] refreshDecisions — generated 2 cards                         ← 只生成 2 张
```

`hasAccount` 的振荡指向 **ViewModel 被反复销毁重建**；`2 cards` 指向 **数据管道规则触发不足**。

---

## 3. 根因 & 修复

### Bug 1：ContentView `.id()` 导致 ViewModel 重建

**根因**：

```swift
// ContentView.swift — 修复前
ContentViewInner(...)
    .id(appState.currentLanguage.rawValue)  // ← 这行
```

`appState.currentLanguage` 在初始化时从 `UserDefaults` 异步读取，值可能在极短窗口内变化。`.id()` 检测到变化 → 立即销毁并重建 `ContentViewInner` → 内部所有 `@State` ViewModel（包括 `decisionsVM`）全部重置 → `hasAccount` 从 true 跌回 false。

**修复**：删除 `.id()`。语言切换由 `loc()` → `LanguageStore.shared` 单例自然驱动，无需强制重建 View 树。

### Bug 2：`hasData` 与 `cards` 脱节

**根因**：

```swift
// refreshDecisions() 中
hasData = !snapshots.isEmpty    // ← 取决于原始数据
cards = CardGenerator.generate() // ← 即使 snapshot 为空也能生成 3-4 张
```

FeatureExtractor 在无 snapshot 时仍能从 metrics 计算基线值 → CardGenerator 生成卡片 → 但 `hasData = false` → View 判断 `viewModel.hasData` 为 false → 显示 EmptyState 而非卡片。

**修复**：View 层改用 `!viewModel.cards.isEmpty` 判断是否展示卡片。

### Bug 3：CardGenerator 规则阈值过高 + 回退卡片重复

**根因**：

| 规则 | 原阈值 | 真实数据表现 |
|------|--------|------------|
| Primary | `topScore > 0.5` | 偶尔触发 |
| Alert | `posts7d > threshold` | 极少触发 |
| Recovery | `recoveryNeeded > 0.5` | 极少触发 |
| Insight | 始终生成 | 始终 |

真实数据仅触发 2 条规则 → 只生成 2 张卡片。`while cards.count < 4` 回退循环又生成相同 `.insight` 模板 → 标题全部重复。

**修复**：

- Primary 阈值 `0.5 → 0.3`，Recovery 阈值 `0.5 → 0.3`
- 疲劳阈值 `max(3.0, avg*1.5) → max(2.0, avg*1.2)`
- `.insight` 新增 `variation: Int` 参数：`0`=时间 / `1`=内容策略 / `2`=互动技巧 / `3`=增长机会
- 回退卡片每张使用不同 `variation` + 不同 `bestDay`，确保标题和内容不重复

---

## 4. 修改文件

| 文件 | 改动 |
|------|------|
| `ContentView.swift` | 删除 `.id(appState.currentLanguage.rawValue)` |
| `DecisionsView.swift` | `hasData` → `!cards.isEmpty` |
| `CardGenerator.swift` | 阈值下调 + fallback 变体卡片 |
| `FeatureExtractor.swift` | 疲劳阈值下调 |
| `ActionCard.swift` | `.insight` 新增 `variation` 参数 |
| `L10n.swift` | 新增 `insightContent/Engagement/Growth` 3 个 key |
| `Localizable.xcstrings` | 对应 4 语言翻译 |

---

**报告完。**
