# Lambda-2 主题与趋势图表设计规范

> 从 gamma-2 分支提取的核心设计：6 套主题 + Trends 条形统计图改造。  
> 已排除的主题：Midnight Pro、Instagram Noir、Warm Amber、Ocean、Twilight。

---

## 1. 主题系统（6 套）

### 1.1 主题列表

| # | Theme | `isDark` | Liquid Glass | 风格 |
|---|-------|:---:|:---:|------|
| 1 | **Apple Native** | ❌ | ✅ | iOS 原生系统色，自适应明暗 |
| 2 | **Instagram** | ❌ | ✅ | Instagram 品牌粉橙暖色调 |
| 3 | **Apple Dark** | ✅ | ✅ | iOS 原生暗色，`Color(.systemBackground)` |
| 4 | **Forest** | ❌ | ✅ | 浅薄荷绿渐变，自然平静 |
| 5 | **Rose Gold** | ❌ | ✅ | 暖玫瑰金，柔和优雅 |
| 6 | **Mono Stone** | ❌ | ❌ | 中性石板灰，极简无色彩 |

### 1.2 `isDark` 替代手动颜色方案

- 不再需要 System / Light / Dark Picker
- 删除了 `AppState.colorScheme` 和 Settings 中的颜色方案 Section
- `FollowerApp` 中 `.preferredColorScheme(theme.isDark ? .dark : .light)` 自动跟随主题
- 选择暗色主题 → 系统强制 dark mode → Material、系统色自动变暗
- 选择亮色主题 → light mode

### 1.3 页面渐变背景

每套主题新增两个属性：

```swift
let backgroundGradientStart: Color  // 渐变起始色（顶部）
let backgroundGradientEnd: Color    // 渐变结束色（底部）
```

`ContentView` 和所有页面通过 `ZStack { LinearGradient + ScrollView/List }` 结构渲染全屏背景。渐变层单独置于 ZStack 底部 `.ignoresSafeArea()`，不随内容滚动，避免闪烁。

### 1.4 LiquidGlassCard — 统一毛玻璃卡片

```swift
.background(
    ZStack {
        RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)  // 采样背景→模糊
        RoundedRectangle(cornerRadius: 16).fill(theme.cardSurface)  // 主题色叠加
    }
)
```

- `.regularMaterial` 采样背后渐变产生高斯模糊
- `theme.cardSurface` 叠加主题色，使卡片与背景颜色协调
- 暗主题 `cardSurface` 低透明度（`white.opacity(0.06)`），亮主题高透明度（`white.opacity(0.85)`）
- 所有卡片组件（`StatCard`、`TrendChart`、`summaryItem`）统一使用 `.liquidGlassCard()`

### 1.5 Apple Dark 示例

```swift
static let appleDark = Theme(
    backgroundPrimary:       Color(.systemBackground),
    backgroundGradientStart: Color(.systemBackground),
    backgroundGradientEnd:   Color(.secondarySystemBackground),
    cardSurface:             Color(.secondarySystemGroupedBackground),
    accentPrimary:           .blue,
    isDark:                  true,
    liquidGlassEnabled:      true
)
```

使用系统语义色 `Color(.systemBackground)` 等，当 `isDark: true` 驱动 `preferredColorScheme(.dark)` 时，自动渲染为原生暗色。

---

## 2. Trends 条形统计图

### 2.1 改造点

| 维度 | 旧（Alpha/Beta） | 新（Lambda-2） |
|------|-----------------|----------------|
| 图表类型 | `LineMark` + `AreaMark` 折线图 | `BarMark` 竖条柱状图 |
| 布局 | 横向 Picker 选指标 → 单图 | 纵向 `ScrollView` 堆叠 6 个图表 |
| 数据加载 | 按选中 `MetricType` 分别 fetch | 一次 fetch 全部类型，`partitionByType` 分组 |
| 窗口切换 | 重新 fetch | 内存切换（3 路 `async let` 预加载） |

### 2.2 TrendChart 组件

```
┌──────────────────────────────────┐
│  指标名 — 窗口 (日/周/月)          │
│  ┌──────────────────────────────┐│
│  │ ██ ██                        ││  ← BarMark
│  │ ██ ██ ██ ██                  ││     渐变填充：barGradientStart → barGradientEnd
│  │ ██ ██ ██ ██ ██ ██           ││     宽度：barWidthRatio 按数据量等比
│  │ ...                          ││     高度：200pt
│  │ 03  04  05  06  07  08  09   ││
│  └──────────────────────────────┘│
└──────────────────────────────────┘
.liquidGlassCard()
```

### 2.3 Bar 宽度等比规则

```swift
static func barWidthRatio(for count: Int) -> Double {
    switch count {
    case ...4:  return 0.90   // 周 (4 bars)
    case 5...7: return 0.80   // 日 (7 bars)
    case 8...12: return 0.70  // 月 (12 bars)
    case 13...24: return 0.60 // 季
    default: return 0.50      // 年 (52+)
    }
}
```

通过 `BarMark(..., width: .ratio(ratio))` 应用。数据越少 bar 越宽，视觉上充实紧凑。

### 2.4 TrendsViewModel 数据模型

```swift
// 6 个始终可见的核心指标
static let visibleMetricTypes: [MetricType] = [
    .followerGrowth, .engagementTrend, .averageLikes,
    .averageComments, .averageShares, .profileViews
]

// 三窗口数据 — 按 metricType 分组存储
@Published var dailyMetrics:   [MetricType: [Metric]] = [:]
@Published var weeklyMetrics:  [MetricType: [Metric]] = [:]
@Published var monthlyMetrics: [MetricType: [Metric]] = [:]

// 按当前窗口返回某指标的 chart data
func chartData(for metricType: MetricType) -> [TrendDataPoint] { ... }
```

`loadTrends()` 使用 3 路 `async let` 并行 fetch 三个窗口的全量数据（`MetricRepository.fetch(accountId:window:from:to:)` 不按 metricType 过滤），然后 `partitionByType` 按类型分组。窗口切换（`selectWindow`）不需要重新 fetch。

### 2.5 页面布局

```
NavigationStack
  ScrollView (vertical)
    SegmentedPicker (日 / 周 / 月)
    ForEach(visibleMetricTypes) { type in
        TrendChart(chartData(for: type))
    }
    GrowthSummary (LazyVGrid 2列, 展示各指标绝对变化)

底部不再有横向 `metricTypePicker`。
```

---

## 3. 关键架构决策

- **`preferredColorScheme` 由 `isDark` 驱动**，删除手动颜色方案 Picker
- **页面背景渐变替代纯色**，`ZStack` 分层确保不随滚动闪烁
- **全部卡片统一 `liquidGlassCard()`**，`regularMaterial` + `theme.cardSurface` 双保险
- **BarMark + 等比宽度**，柱状图宽度随数据量自适应
- **Trends 一次 fetch + 内存分区**，日/周/月切换零延迟
