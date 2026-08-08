# Growth Decision Engine — 增长决策引擎

> **版本**：Alpha 1.0
> **定位**：独立 Tab，位于趋势（Trends）之后
> **核心思想**：规则驱动的决策系统，将历史数据转化为可执行行动卡片

---

## 1. 概述

### 1.1 这个功能是什么

**不是 AI**，而是一个 **Growth Decision Engine（增长决策引擎）**。

```
Input:  Instagram 历史数据 (posts / followers / engagement / time series)
Output: 今日行动卡片 (Action Cards)
```

本质是 **规则驱动的决策系统**，具有三个关键优势：

| 特性 | AI 方案 | 规则引擎方案 |
|------|--------|------------|
| 可解释性 | 黑盒，用户不知道为什么 | 每张卡片有明确的 "Why" |
| 可控性 | 需重新训练 | 直接调整评分权重 |
| 稳定性 | 可能 hallucinate | 确定性输出，不会胡说 |

### 1.2 Tab 位置

```
TabView
├── Dashboard      (仪表盘)
├── Trends         (趋势图表)
├── Decisions      (增长决策)  ← NEW
└── Settings       (我的)
```

---

## 2. 系统架构

### 2.1 四层流水线

```
┌─────────────────────────────────────────────┐
│  [1] Data Layer          原始数据             │
│      posts / followers / engagement /        │
│      time series / snapshots                 │
├─────────────────────────────────────────────┤
│  [2] Feature Layer       特征提取             │
│      ContentPerformance / FollowerHealth /   │
│      TimingProfile / FatigueIndex            │
├─────────────────────────────────────────────┤
│  [3] Scoring Engine      评分系统             │
│      ContentScore / GrowthScore /            │
│      RecoveryScore / AlertScore              │
├─────────────────────────────────────────────┤
│  [4] Card Generator      UI 卡片生成          │
│      ActionCard / AlertCard / RecoveryCard   │
└─────────────────────────────────────────────┘
```

### 2.2 数据流

```swift
// 1. Data input
let posts = repo.fetchRecentPosts(days: 30)
let snapshots = repo.fetchSnapshots(days: 90)
let metrics = repo.fetchMetrics(types: allTypes)

// 2. Feature extraction
let features = FeatureExtractor.extract(posts: posts,
                                         snapshots: snapshots,
                                         metrics: metrics)

// 3. Scoring
let scores = ScoringEngine.score(features)

// 4. Card generation
let cards = CardGenerator.generate(scores)
```

---

## 3. 数据层 (Data Layer)

### 3.1 输入数据源

| 数据 | 来源 | 时间范围 |
|------|------|---------|
| Posts (帖子) | `MockPostGenerator` → 后续 Event/Snapshot | 30 天 |
| Followers (粉丝) | `SnapshotRepository.latest()` | 实时 |
| Engagement (互动) | `SnapshotRepository.fetch()` | 7/30/90 天 |
| Metrics (指标) | `MetricRepository.fetch()` | 7/30/90 天 |

### 3.2 数据结构

```swift
/// 内容条目 — 单条帖子的互动数据
struct ContentItem: Sendable {
    let id: String
    let type: ContentType          // reel / carousel / photo
    let likes: Int
    let comments: Int
    let shares: Int
    let postedAt: Date
}

/// 内容类型枚举
enum ContentType: String, Sendable {
    case reel
    case carousel
    case photo
}
```

---

## 4. 特征层 (Feature Layer)

### 4.1 特征提取器

```swift
/// 特征提取结果 — 所有可评分维度的聚合
struct GrowthFeatures: Sendable {
    /// 每种内容类型的表现统计
    let contentPerformance: [ContentType: ContentStats]

    /// 粉丝健康度
    let followerHealth: FollowerHealth

    /// 时间画像
    let timingProfile: TimingProfile

    /// 疲劳指数
    let fatigueIndex: FatigueIndex
}
```

### 4.2 内容表现特征

```swift
/// 单种内容类型的统计
struct ContentStats: Sendable {
    let type: ContentType
    let avgEngagement: Double       // 平均互动率（likes+comments+shares）/ followers
    let totalPosts: Int             // 该类型帖子总数
    let recentPosts: Int            // 最近 7 天该类型帖子数
    let growthRate: Double          // 互动增长趋势（正=上升，负=下降）
}
```

**计算示例**：
```
Reel avg engagement   = 4.2%
Carousel avg engagement = 2.1%
Photo avg engagement   = 1.3%
```

### 4.3 粉丝健康度

```swift
/// 粉丝健康度分析
struct FollowerHealth: Sendable {
    let activeFollowers: Int        // 近 7 天互动过的粉丝
    let inactiveFollowers: Int      // 关注但 30 天无互动
    let totalFollowers: Int
    let activeRatio: Double         // active / total
    let followerGrowth7d: Double    // 7 天净增长
    let followerGrowth30d: Double   // 30 天净增长
}
```

**示例**：
```
active_followers    = 1,800 (18%)
inactive_followers  = 6,200 (62%)
dead_followers      = 2,000 (20%)
```

### 4.4 时间画像

```swift
/// 发帖时间效果分析
struct TimingProfile: Sendable {
    let bestHours: ClosedRange<Int>     // 最佳发帖时段
    let worstHours: ClosedRange<Int>    // 最差发帖时段
    let bestDay: Int                    // 最佳发帖星期几（1=Sun...7=Sat）
}
```

**示例**：
```
best_post_time  = 19:00–21:00
worst_post_time = 03:00–06:00
best_day        = Wednesday
```

### 4.5 疲劳指数

```swift
/// 内容疲劳检测
struct FatigueIndex: Sendable {
    let contentType: ContentType
    let posts7d: Int                // 7 天内发帖数
    let engagementTrend: Double     // 互动变化趋势
    let isFatigued: Bool            // 是否过度发布
    let penalty: Double             // 疲劳扣分 (0.0 ~ 0.5)
}
```

**规则**：
```
if posts_of_type > 5 in last 7 days:
    isFatigued = true
    penalty = 0.3
```

---

## 5. 评分引擎 (Scoring Engine)

### 5.1 评分模型

```swift
/// 评分引擎 — 为每种增长行为打分，决定今日行动优先级
struct ScoringEngine: Sendable {

    /// 内容类型得分
    static func scoreContentType(_ stats: ContentStats,
                                  fatigue: Double) -> Double {
        let baseScore = stats.avgEngagement * 0.5
                      + stats.growthRate * 0.3
                      - fatigue * 0.2
        return min(1.0, max(0.0, baseScore))
    }

    /// 增长健康得分
    static func scoreGrowthHealth(_ health: FollowerHealth) -> Double {
        let growthScore = clamp(health.followerGrowth7d / 100.0, 0, 1) * 0.4
        let activeScore = health.activeRatio * 0.6
        return growthScore + activeScore
    }

    /// 恢复需求得分（越高越需要恢复操作）
    static func scoreRecoveryNeeded(_ health: FollowerHealth) -> Double {
        guard health.activeRatio < 0.5 else { return 0 }
        return (0.5 - health.activeRatio) * 2.0  // 0.0 ~ 1.0
    }
}
```

### 5.2 权重配置

| 因子 | 权重 | 说明 |
|------|------|------|
| avgEngagement | 0.5 | 平均互动率 — 最重要的指标 |
| growthRate | 0.3 | 增长趋势 — 是否有动量 |
| fatiguePenalty | -0.2 | 疲劳惩罚 — 过度发布会扣分 |

### 5.3 评分输出

```swift
/// 评分结果汇总
struct GrowthScores: Sendable {
    /// 内容类型得分（按分数降序）
    let contentScores: [(ContentType, Double)]

    /// 粉丝健康得分 (0.0 ~ 1.0)
    let growthHealth: Double

    /// 恢复需求得分 (0.0 ~ 1.0)
    let recoveryNeeded: Double

    /// 疲劳检测结果
    let fatiguedTypes: [ContentType]
}
```

**示例输出**：
```
Reel:     0.87  ← 最高
Carousel: 0.52
Photo:    0.31

Growth Health:   0.68
Recovery Needed: 0.64
Fatigued Types:  [Carousel]
```

---

## 6. 卡片生成器 (Card Generator)

### 6.1 卡片类型

```swift
/// 行动卡片类型
enum CardType: String, Sendable {
    case primary     // 🔥 今日主行动
    case alert       // ⚠️ 疲劳/异常提醒
    case recovery    // ⚡ 恢复增长建议
    case insight     // 💡 通用洞察
}

/// 行动卡片
struct ActionCard: Identifiable, Sendable {
    let id: String             // UUID
    let type: CardType
    let icon: String           // SF Symbol name
    let title: String
    let actions: [String]      // 建议的具体行动
    let reason: String         // 为什么推荐
    let impact: String?        // 预期效果
    let priority: Int          // 排序优先级（越小越靠前）
}
```

### 6.2 生成规则

```swift
/// 卡片生成器 — 将评分结果转化为 UI 卡片
enum CardGenerator: Sendable {

    /// 主入口：根据评分生成全部卡片
    static func generate(scores: GrowthScores,
                         features: GrowthFeatures) -> [ActionCard] {
        var cards: [ActionCard] = []

        // Rule 1: 最高分内容类型 → Primary Action Card
        if let top = scores.contentScores.first, top.1 > 0.8 {
            cards.append(primaryCard(for: top.0, stats: features.contentPerformance[top.0]!))
        }

        // Rule 2: 疲劳检测 → Alert Card
        for type in scores.fatiguedTypes {
            cards.append(fatigueCard(for: type))
        }

        // Rule 3: 粉丝不活跃 → Recovery Card
        if scores.recoveryNeeded > 0.5 {
            cards.append(recoveryCard(health: features.followerHealth))
        }

        // Rule 4: 通用洞察（始终生成至少一张）
        if let insight = insightCard(scores: scores) {
            cards.append(insight)
        }

        return cards.sorted { $0.priority < $1.priority }
    }
}
```

### 6.3 卡片模板

#### Primary Card（主行动）

```
🔥 BOOST GROWTH TODAY

→ Post 1 Reel (highest ROI format)
→ Engage 5 high-value followers
→ Reply to top comments

Why:
Reels outperform other formats by 2.3x

Expected:
+80 ~ +150 followers
```

#### Alert Card（疲劳提醒）

```
⚠️ CONTENT FATIGUE

Carousel performance ↓28%
Posting frequency too high

Suggestion:
Reduce carousel posts this week
```

#### Recovery Card（恢复增长）

```
⚡ ENGAGEMENT RECOVERY

62% followers inactive

Actions:
→ DM 3 active supporters
→ Re-engage top commenters
```

---

## 7. UI 设计

### 7.1 页面结构

```
NavigationStack
└── ZStack
    ├── 主题渐变背景
    └── ScrollView
        ├── Hero Summary        // 今日决策摘要
        ├── Action Cards        // 行动卡片列表（垂直堆叠）
        │   ├── Primary Card    // 主行动（优先展示）
        │   ├── Alert Card      // 提醒（如有）
        │   ├── Recovery Card   // 恢复（如有）
        │   └── Insight Card    // 洞察（始终至少一张）
        └── Refresh Button      // 手动重新分析
```

### 7.2 卡片视觉设计

每个卡片：
- `.regularMaterial` 毛玻璃背景
- 左侧彩色竖线（`CardType` → 颜色）
- SF Symbol 图标 + 标题
- 行动列表（bullet points）
- 原因说明（caption 字体）
- 预期效果（可选的 badge）

| CardType | 颜色 | 图标 |
|----------|------|------|
| primary | `theme.accentPrimary` | `flame.fill` |
| alert | `theme.warningOrange` | `exclamationmark.triangle.fill` |
| recovery | `theme.positiveGreen` | `arrow.up.heart.fill` |
| insight | `theme.textSecondary` | `lightbulb.fill` |

### 7.3 交互设计

| 手势 | 行为 |
|------|------|
| 卡片内点击 | 展开/折叠详细解释 |
| 下拉刷新 | 重新拉取数据 + 重新评分 + 重新生成卡片 |
| 卡片长按 | 复制建议文本（分享用） |

---

## 8. MVVM 架构

### 8.1 文件结构

```
Features/Decisions/
├── DecisionsView.swift          // Tab 页面
├── DecisionsViewModel.swift     // 数据加载 + 评分触发
├── ActionCardView.swift         // 单个行动卡片组件
└── HeroSummaryView.swift        // 顶部决策摘要

Services/Decisions/
├── FeatureExtractor.swift       // 特征提取器
├── ScoringEngine.swift          // 评分引擎
├── CardGenerator.swift          // 卡片生成器

Models/
├── ActionCard.swift             // 卡片数据模型
├── GrowthFeatures.swift         // 特征数据结构
└── GrowthScores.swift           // 评分结果模型
```

### 8.2 依赖关系

```
DecisionsViewModel
├── snapshotRepo     // 现有
├── metricRepo       // 现有
├── accountRepo      // 现有
├── FeatureExtractor // 新增
├── ScoringEngine    // 新增（纯函数，无状态）
└── CardGenerator    // 新增（纯函数，无状态）
```

### 8.3 DecisionsViewModel

```swift
/// 增长决策页 ViewModel — 加载数据、提取特征、触发评分、生成卡片
@Observable
final class DecisionsViewModel {
    private let snapshotRepo: SnapshotRepositoryProtocol
    private let metricRepo: MetricRepositoryProtocol
    private let accountRepo: AccountRepositoryProtocol

    /// 生成的行动卡片列表
    var cards: [ActionCard] = []

    /// 特征数据（用于调试）
    var features: GrowthFeatures?
    var scores: GrowthScores?

    /// 加载数据 → 提取特征 → 评分 → 生成卡片
    func refreshDecisions() async {
        // 1. 拉取原始数据
        // 2. FeatureExtractor.extract()
        // 3. ScoringEngine.score()
        // 4. CardGenerator.generate()
        // 5. cards = result
    }
}
```

---

## 9. 后续迭代

### Alpha 1.0（本阶段）
- [ ] 基础四层流水线
- [ ] 3 种卡片类型（Primary / Alert / Recovery）
- [ ] Mock 数据支持
- [ ] 独立 Tab 接入

### Beta 1.1
- [ ] 真实数据管道（替换 Mock）
- [ ] 更多特征维度（标签分析、频次优化）
- [ ] 卡片展开/折叠动画
- [ ] 多语言支持

### Beta 1.2
- [ ] Fatigue 疲劳算法优化
- [ ] 自定义权重面板（高级用户可调权重）
- [ ] 决策历史记录
- [ ] 卡片分享功能

---

## 10. 与现有系统的关系

| 现有模块 | 关系 |
|---------|------|
| Dashboard | Decisions 不替代 Dashboard — Dashboard 是数据展示，Decisions 是行动建议 |
| Trends | Trends 帮助用户"看"，Decisions 帮助用户"做" |
| Premium | 所有 Scoring Engine 功能默认免费；高级自定义权重为 Premium |
| SyncEngine | 每次 sync 后自动触发 refreshDecisions() |

---

**文档完。**
