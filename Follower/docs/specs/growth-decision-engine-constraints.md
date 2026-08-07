# Growth Decision Engine — 实现约束与注意事项

> **关联文档**：[growth-decision-engine.md](growth-decision-engine.md)
> **版本**：Alpha 1.0

---

## 1. MVVM 架构约束

### 1.1 层级职责

```
┌──────────────────────────────────────────────────┐
│  View                   仅展示 + 触发交互          │
│  → 不直接访问数据库                               │
│  → 不包含业务逻辑                                 │
│  → 通过 ViewModel 获取数据                        │
├──────────────────────────────────────────────────┤
│  ViewModel              状态管理 + 编排            │
│  → @Observable 类（Swift 6）                      │
│  → 调用 Service / Repository                     │
│  → 不直接处理 I/O                                 │
├──────────────────────────────────────────────────┤
│  Service                无状态纯计算               │
│  → FeatureExtractor / ScoringEngine / CardGenerator│
│  → 纯函数，Sendable，不持有状态                    │
├──────────────────────────────────────────────────┤
│  Model                  数据结构                  │
│  → ActionCard / GrowthFeatures / GrowthScores     │
│  → 仅定义属性，无逻辑                             │
└──────────────────────────────────────────────────┘
```

### 1.2 强制规则

| 规则 | 说明 |
|------|------|
| View 不能 import GRDB | 数据库访问仅限 Repository |
| ViewModel 不能 import SwiftUI | 使用 `@Observable`，非 `@ObservableObject` |
| Service 必须标记 `Sendable` | Swift 6 并发安全 |
| Model 必须标记 `Sendable` | 所有 struct/enum 符合 Swift 6 Sendable |
| View 用 `@Environment(AppState.self)` | 不创建自己的 `@State appState` |
| ViewModel 用 `@Observable` | 非 `@ObservableObject` + `@Published` |

---

## 2. Swift 6 编写规范

### 2.1 必须遵守

```swift
// ✅ ViewModel — @Observable（Swift 6 新 Observation 框架）
@Observable
final class DecisionsViewModel {
    var cards: [ActionCard] = []
    var isLoading: Bool = false
}

// ✅ Service — Sendable + 纯函数
struct ScoringEngine: Sendable {
    static func score(_ features: GrowthFeatures) -> GrowthScores { ... }
}

// ✅ Model — Sendable struct
struct ActionCard: Identifiable, Sendable {
    let id: String
    let type: CardType
    ...
}

// ✅ View — @Environment(AppState.self)
struct DecisionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(DecisionsViewModel.self) private var viewModel
    ...
}
```

### 2.2 禁止使用

```swift
// ❌ ObservableObject + @Published（旧模式）
final class OldViewModel: ObservableObject {
    @Published var cards: [ActionCard] = []
}

// ❌ @EnvironmentObject（旧模式）
@EnvironmentObject var appState: AppState

// ❌ @StateObject / @ObservedObject（旧模式）
@StateObject var viewModel = DecisionsViewModel()

// ❌ View 内创建 AppState
@State private var appState = AppState(...)

// ❌ 非 Sendable 的共享可变状态
class SharedState { var value = 0 }
```

---

## 3. CI / 测试约束

### 3.1 测试分层

```
测试
├── 确定性测试（必须通过）
│   ├── ScoringEngine 纯函数测试
│   ├── CardGenerator 规则测试
│   ├── FeatureExtractor 计算测试
│   ├── Model Codable 往返测试
│   └── GrowthScores 排序逻辑测试
│
└── 不可控测试（允许失败）
    ├── ViewModel @Observable 集成测试
    ├── UI 测试（时序依赖）
    └── DB 依赖测试（共享状态）
```

### 3.2 ios-ci.yml 配置

```yaml
# 确定性测试 — 写入 must-pass
-only-testing:FollowerTests/DecisionsEngineTests \
-only-testing:FollowerTests/ModelsTests \
-only-testing:FollowerTests/ThemeTests \
-only-testing:FollowerTests/LambdaTests \
-only-testing:FollowerTests/PremiumServicesTests \

# 不可控测试 — 写入 flaky
-only-testing:FollowerTests/DecisionsViewModelTests \
|| true
```

### 3.3 禁止本地运行测试

- 所有测试验证通过 CI（GitHub Actions）
- 本地仅执行 `xcodebuild build`
- 不在本地执行 `xcodebuild test`

---

## 4. UI 设计约束

### 4.1 必须遵循 APP 原有风格

| 元素 | 规范 |
|------|------|
| 背景 | `ZStack { LinearGradient(theme.backgroundGradientStart, theme.backgroundGradientEnd) }` |
| 卡片 | `.background(.regularMaterial)` + `RoundedRectangle(cornerRadius: 16)` |
| 文字 | `theme.textPrimary` / `theme.textSecondary` / `theme.textTertiary` |
| 主题色 | `theme.accentPrimary` / `theme.positiveGreen` / `theme.negativeRed` |
| 分割线 | `theme.divider` |
| 图标 | SF Symbols，`foregroundColor` 使用 theme token |

### 4.2 禁止

```swift
// ❌ 硬编码颜色
.foregroundColor(.blue)
.foregroundColor(.orange)

// ❌ 硬编码字体大小（除非有特殊设计需求）
.font(.title)  // 可用但尽量保持一致

// ❌ 忽略 Dark Mode
.background(Color.white)
```

### 4.3 渐变背景模板

```swift
ZStack {
    LinearGradient(
        colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
        startPoint: .top, endPoint: .bottom
    ).ignoresSafeArea()

    ScrollView {
        // content
    }
    .scrollContentBackground(.hidden)
}
```

---

## 5. 五种 UI 视觉方案

> 以下 5 套方案共享同一个 ViewModel 和数据管道，仅 View 层的卡片布局和视觉风格不同。

---

### 方案 A：Stack Cards（堆叠卡片）

**风格**：经典垂直堆叠，最接近现有 Dashboard Premium 卡片设计。

```
┌────────────────────────────────┐
│  🔥 BOOST GROWTH TODAY         │
│  → Post 1 Reel                 │
│  → Engage 5 followers          │
│  Why: Reels 2.3x more engaging │
├────────────────────────────────┤
│  ⚠️ CONTENT FATIGUE            │
│  Carousel ↓28%                 │
│  → Reduce carousel posts       │
├────────────────────────────────┤
│  ⚡ ENGAGEMENT RECOVERY         │
│  62% followers inactive        │
│  → DM 3 active supporters      │
└────────────────────────────────┘
```

### 方案 B：Timeline Feed（时间线流）

**风格**：类似 Instagram Feed 的时间线卡片，每张卡片有"头像+时间戳"的社交感。

```
┌────────────────────────────────┐
│  ● Today · 9:00 AM             │
│  ┌──────────────────────────┐  │
│  │ 🔥 BOOST GROWTH TODAY    │  │
│  │ Post 1 Reel              │  │
│  │ Reels 2.3x more engaging │  │
│  │              +80 followers│  │
│  └──────────────────────────┘  │
│  ● Today · 9:01 AM             │
│  ┌──────────────────────────┐  │
│  │ ⚠️ CONTENT FATIGUE       │  │
│  │ Carousel ↓28%            │  │
│  └──────────────────────────┘  │
└────────────────────────────────┘
```

### 方案 C：Dashboard Grid（仪表盘网格）

**风格**：2 列网格，每张卡片紧凑排列，类似 Apple Fitness 摘要环。

```
┌──────────────┬──────────────┐
│  🔥          │  ⚡           │
│  POST REEL   │  RECOVERY    │
│  +80 est.    │  62% inactive│
│              │              │
├──────────────┼──────────────┤
│  ⚠️          │  💡           │
│  FATIGUE     │  INSIGHT     │
│  Carousel ↓  │  Best time   │
│              │  7PM Wed     │
└──────────────┴──────────────┘
```

### 方案 D：Carousel Pager（轮播翻页）

**风格**：水平 TabView 翻页，每页一张完整卡片，类似 App Store Today 卡片。

```
     ← swipe →
┌────────────────────────────────┐
│                                │
│         🔥 BOOST GROWTH        │
│            TODAY               │
│                                │
│     Post 1 Reel                │
│     Engage 5 followers         │
│                                │
│     ──── ● ○ ○ ────            │
│                                │
└────────────────────────────────┘
```

### 方案 E：Compact List（紧凑列表）

**风格**：系统原生 List 风格，每行一行文字 + 右箭头，点击展开详情。

```
┌────────────────────────────────┐
│  🔥 Post 1 Reel today     ›    │
│     +80 followers expected     │
├────────────────────────────────┤
│  ⚠️ Reduce carousel posts  ›   │
│     Performance ↓28%           │
├────────────────────────────────┤
│  ⚡ Re-engage followers    ›    │
│     62% inactive               │
├────────────────────────────────┤
│  💡 Best time: Wed 7PM    ›    │
│     Engagement peak            │
└────────────────────────────────┘
```

---

## 6. 五种方案的 #Preview 代码骨架

### 方案 A — Stack Cards

```swift
#Preview("方案 A — Stack Cards") {
    let sample = ActionCard.sampleCards
    return NavigationStack {
        DecisionsStackView(cards: sample)
    }
}
```

### 方案 B — Timeline Feed

```swift
#Preview("方案 B — Timeline Feed") {
    let sample = ActionCard.sampleCards
    return NavigationStack {
        DecisionsTimelineView(cards: sample)
    }
}
```

### 方案 C — Dashboard Grid

```swift
#Preview("方案 C — Dashboard Grid") {
    let sample = ActionCard.sampleCards
    return NavigationStack {
        DecisionsGridView(cards: sample)
    }
}
```

### 方案 D — Carousel Pager

```swift
#Preview("方案 D — Carousel Pager") {
    let sample = ActionCard.sampleCards
    return NavigationStack {
        DecisionsCarouselView(cards: sample)
    }
}
```

### 方案 E — Compact List

```swift
#Preview("方案 E — Compact List") {
    let sample = ActionCard.sampleCards
    return NavigationStack {
        DecisionsListView(cards: sample)
    }
}
```

---

## 7. ActionCard 示例数据（供 Preview 使用）

```swift
extension ActionCard {
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
```

---

## 8. 文件清单

### 需要创建的文件

```
Follower/Models/
├── ActionCard.swift              // ActionCard + CardType
├── GrowthFeatures.swift          // GrowthFeatures + ContentStats + FollowerHealth + TimingProfile + FatigueIndex
└── GrowthScores.swift            // GrowthScores

Follower/Services/Decisions/
├── FeatureExtractor.swift        // 特征提取器
├── ScoringEngine.swift           // 评分引擎
└── CardGenerator.swift           // 卡片生成器

Follower/Features/Decisions/
├── DecisionsView.swift           // 主视图（调度器，可选方案）
├── DecisionsViewModel.swift      // ViewModel
├── DecisionsStackView.swift      // 方案 A
├── DecisionsTimelineView.swift   // 方案 B
├── DecisionsGridView.swift       // 方案 C
├── DecisionsCarouselView.swift   // 方案 D
├── DecisionsListView.swift       // 方案 E
└── ActionCardRow.swift           // 通用卡片行组件

FollowerTests/
└── DecisionsEngineTests.swift    // 确定性测试

FollowerUITests/
└── DecisionsUITests.swift        // UI 测试
```

---

## 9. 实施顺序

| Step | 内容 | 依赖 |
|------|------|------|
| 1 | 创建 Model（ActionCard / GrowthFeatures / GrowthScores） | 无 |
| 2 | 创建 Service（FeatureExtractor / ScoringEngine / CardGenerator） | Step 1 |
| 3 | 创建 DecisionsViewModel | Step 2 |
| 4 | 创建 5 套 UI + Preview | Step 1, 3 |
| 5 | 创建 DecisionsView（主调度器） | Step 4 |
| 6 | 接入 TabView（ContentView） | Step 5 |
| 7 | 编写确定性测试 | Step 2 |
| 8 | 更新 ios-ci.yml | Step 7 |

---

**文档完。**
