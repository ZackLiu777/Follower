# TrendChart 周视图渲染 Bug 复盘报告

> **项目**：Follower (iOS) · **模块**：TrendsView / TrendChart / TrendsViewModel
> **框架**：SwiftUI Charts
> **修复轮次**：4 轮迭代
> **报告日期**：2026-06-30

---

## 1. 概述 / Overview

本报告复盘 Follower App Trends 页面 TrendChart 组件在周视图（`.week`）渲染过程中暴露的 4 个核心 Bug。这 4 个 Bug 在表面上都呈现为"柱子显示异常"，但根因分别属于**视觉层**、**数据层**、**语义层**和**数据源错配** 4 个不同维度，导致前几轮修复都是"治标不治本"——修了 A 暴露 B，修了 B 暴露 C，最终在 4 轮迭代后才彻底闭环。

报告目的有三：

1. **复盘 Bug 演变路径**：理清每一轮的"现象 → 误判 → 实际根因"，避免下次再走弯路。
2. **提炼根因模式**：把 4 个 Bug 抽象成可复用的 Swift Charts 避坑规则。
3. **形成 Checklist**：未来新增任何时间序列图表时，用 10 条自检清单预防同类问题。

涉及的关键文件：

- `TrendChart.swift` — 图表 UI 组件（BarMark + AxisMarks + domain）
- `TrendsViewModel.swift` — 数据加载与 `chartData(for:)` 聚合入口
- `TrendsView.swift` — 容器视图（本次未改动）

---

## 2. Bug 时间线 / Bug Timeline

### 2.1 Round 1 — Fri/Sat/Sun 柱子凭空消失

**现象**：周视图截图中，X 轴标签 `Mon Tue Wed Thu Fri Sat Sun` 完整显示，但只有 `Mon-Thu` 4 根柱子，`Fri/Sat/Sun` 3 根完全空白。

**当时误判**：怀疑是 `barWidth` 太大导致柱子互相覆盖、或 `clipShape(RoundedRectangle)` 圆角裁切了柱子。

**实际根因**：`xScaleDomain` 用了"固定自然周 Mon→Sun"语义，而 Preview 数据是"今天向前滚动 7 天"。今天是周四时，上周 Fri/Sat/Sun 的 3 个数据点落在 domain 左边界外，被 Swift Charts 静默裁剪（domain 外的 `BarMark` 不渲染，无 warning）。

### 2.2 Round 2 — 周视图从周二开始而非周一

**现象**：修复 Round 1 后，柱子数量恢复正常，但 X 轴标签变成 `Tue Wed Thu Fri Sat Sun ...`，整组数据向右偏移 1 天。

**当时误判**：怀疑是 `xScaleDomain` 的边界延伸量不够。

**实际根因**：`TimeSeriesEngine.aggregate(_, bucket: .day)` 产出的桶日期是 UTC 末尾（约 23:59 UTC），经本地时区（CST UTC+8）格式化后整体右移 1 天。叠加 `.suffix(7)` 把这批偏移日期原样喂给 Chart，导致周一数据被格式化成 "Tue"。

### 2.3 Round 3 — 周最左侧柱子被左边界裁切 + Year 只剩 1 根柱子

**现象**：周视图最左侧（周一之前）有一根柱子被左边界裁切；年视图只剩 1 根柱子（在 "1"=一月下方），其余 11 个月全空。

**当时误判**：怀疑是 `plotDimension(padding:)` 的 padding 不够，于是不断加大 padding。

**实际根因**：三个 Bug 叠加：

1. `BarMark(.fixed(24))` 中心落在 cell 边界（Mon 00:00），左侧 12pt 在 plot area 外被裁。
2. `AxisMarks(.stride(by: .day, count: 1))` 在 7 天 domain 上产生 8 个 tick（闭区间采样），多出一个下周一。
3. `TrendsViewModel.chartData(.week)` 用"滚动 7 天"语义，`TrendChart.xScaleDomain` 用"固定自然周"语义，两者错配导致数据点落在 domain 外。

### 2.4 Round 4 — 周数据完全看不见（0 根柱子）

**现象**：修复 Round 3 后，周视图 Y 轴显示 `0-1`，7 个 cell 全空，0 根柱子。

**当时误判**：以为对齐逻辑有 bug。

**实际根因**：`weeklyMetrics` 是"周聚合"数据（每周 1 条，共 52 条），不是"过去 7 天的日数据"。用 `isDate(_:inSameDayAs:)` 去匹配当前自然周的 7 天，但周聚合只有 1 条记录且 `observedAt` 不在当前自然周内，所以 7 个 cell 全部返回 0。

---

## 3. 根因深度剖析 / Root Cause Analysis

### 3.1 Bug 1 — Domain 静默裁剪（Silent Clipping）

**视觉证据**：周视图 X 轴 7 个标签完整，但只有 4 根柱子（Mon-Thu），Fri/Sat/Sun 空白。

**错误代码**：

```swift
// TrendChart.swift — 固定自然周 domain
case .week:
    let start = startOfWeek(for: referenceDate)  // 本周一 00:00
    let end = calendar.date(byAdding: .day, value: 7, to: start)!
    return start...end

// #Preview — 滚动 7 天数据
let sample = (0..<7).map { i in
    TrendDataPoint(date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!, ...)
}
```

**为什么错**：Domain 是"自然周 Mon→Sun"，数据是"今天向前 7 天"。今天周四时，上周 Fri/Sat/Sun 落在 domain 外，Swift Charts 对 domain 外的 `BarMark` **直接不渲染且无 warning**，极具迷惑性。

**修复代码**：

```swift
// 统一为"以今天为右端的滚动 7 天"
case .week:
    let today = calendar.startOfDay(for: referenceDate)
    let start = calendar.date(byAdding: .day, value: -6, to: today)!
    let end   = calendar.date(byAdding: .day, value: 1,  to: today)!
    return start...end
```

**为什么修复有效**：Domain 与数据语义完全对齐，7 个数据点全部落在 domain 内。

### 3.2 Bug 2 — 聚合桶时区偏移（Timezone Offset in Aggregation）

**视觉证据**：周视图 X 轴标签变成 `Tue Wed Thu Fri Sat Sun Mon`，整组右移 1 天。

**错误代码**：

```swift
// TrendsViewModel.chartData(.week) — 直接用聚合结果
case .week:
    return TimeSeriesEngine.aggregate(rawMetrics[metricType] ?? [], bucket: .day).suffix(7)
```

**为什么错**：`TimeSeriesEngine.aggregate` 按 day 分桶时，桶日期大概率是 UTC 23:59:59 或 UTC 00:00。当用户在 CST（UTC+8）环境：

| 实际归属日（UTC） | 桶时间（UTC） | 转 CST 后显示为 |
|---|---|---|
| Mon Jun 23 | Mon 23:59 UTC | **Tue** Jun 24 07:59 CST |
| Tue Jun 24 | Tue 23:59 UTC | **Wed** Jun 25 07:59 CST |

`.dateTime.weekday(.abbreviated)` 按本地时区格式化，所以周一数据被格式化成 "Tue"。

**修复代码**：

```swift
// 按本地日重新对齐
case .week:
    let weekStart = startOfWeek(for: Date())
    let aggregated = TimeSeriesEngine.aggregate(rawMetrics[metricType] ?? [], bucket: .day)
    return (0..<7).map { i in
        let dayStart = calendar.date(byAdding: .day, value: i, to: weekStart)!
        let value = aggregated
            .first { calendar.isDate($0.date, inSameDayAs: dayStart) }?
            .value ?? 0
        return TrendDataPoint(date: dayStart, value: value)
    }
```

**为什么修复有效**：数据点日期钉死在本地 `dayStart`，不受 `aggregate` 内部时区影响。

### 3.3 Bug 3 — BarMark 中心在 Cell 边界 + Stride 多 Tick + 语义错配（Triple Bug）

**视觉证据**：周视图最左侧柱子被左边界裁切；年视图 X 轴 13 个标签（多出下一年 1 月）。

**错误代码 1 — fixed width 中心在边界**：

```swift
BarMark(
    x: .value("Date", point.date),  // ← Mon 00:00，等于 domain 左边界
    y: .value("Value", point.value),
    width: .fixed(24)                // ← 中心向两侧各延伸 12pt，左侧被裁
)
```

**错误代码 2 — stride 闭区间采样**：

```swift
AxisMarks(values: .stride(by: .day, count: 1))  // 7 天 domain → 8 个 tick（含下周一）
```

**错误代码 3 — Chart 与 ViewModel 语义不一致**：

```swift
// TrendChart — 固定自然周
let start = startOfWeek(for: referenceDate)  // 本周一

// TrendsViewModel — 滚动 7 天
let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
```

**修复代码（三合一）**：

```swift
// 1. 数据点挪到 cell 中心（每天 12:00）
case .week:
    let weekStart = startOfWeek(for: Date())
    return (0..<7).map { i in
        let dayStart = calendar.date(byAdding: .day, value: i, to: weekStart)!
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)!
        return TrendDataPoint(date: noon, value: ...)
    }

// 2. 柱宽用 ratio 而非 fixed
BarMark(
    x: .value("Date", point.date),
    y: .value("Value", point.value),
    width: .ratio(0.7)  // ← 占 cell 70%，结构性消除裁切
)

// 3. grid line 与 label 拆成两组 AxisMarks
let boundaries = (0...7).map { calendar.date(byAdding: .day, value: $0, to: start)! }  // 8 条边界
let centers = (0..<7).map { /* 每天 12:00 */ }                                            // 7 个中心
AxisMarks(values: boundaries) { _ in AxisGridLine(...) }     // grid line 在边界
AxisMarks(values: centers) { value in AxisValueLabel(...) }  // label 在中心
```

**为什么修复有效**：

- 柱子在 cell 中心 → 两侧天然在 cell 内
- `.ratio()` 让柱宽自适应 cell 宽度，不会越界
- grid line 在边界、label 在中心 → grid line 永远在柱子两侧，不穿过柱子
- Chart 和 ViewModel 都用 `startOfWeek` → 语义一致

### 3.4 Bug 4 — 数据源错配（Data Source Mismatch）

**视觉证据**：周视图 Y 轴 `0-1`，7 个 cell 全空，0 根柱子。

**错误代码**：

```swift
// TrendsViewModel.chartData(.week) — 用 weeklyMetrics
case .week:
    let raw = weeklyMetrics[metricType] ?? []  // ← 周聚合，每周 1 条，共 52 条
    return (0..<7).map { i in
        let dayStart = calendar.date(byAdding: .day, value: i, to: weekStart)!
        let value = raw
            .first { calendar.isDate($0.observedAt, inSameDayAs: dayStart) }?  // ← 周聚合只有 1 条，匹配不到
            .value ?? 0                                                          // ← 全部返回 0
        return TrendDataPoint(date: noon, value: value)
    }
```

**为什么错**：`weeklyMetrics` 是 `metricRepo.fetch(... window: .week, limit: 52)` 返回的**周聚合数据**（每周 1 条），不是"过去 7 天的日数据"。用 `isDate(_:inSameDayAs:)` 去匹配当前自然周的 7 天，但周聚合只有 1 条记录且 `observedAt` 通常是该周末尾，不在当前自然周内，所以 7 个 cell 全为 0。

**修复代码**：

```swift
case .week:
    let raw = dailyMetrics[metricType] ?? []  // ← 改用日数据
    return (0..<7).map { i in
        let dayStart = calendar.date(byAdding: .day, value: i, to: weekStart)!
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)!
        let value = raw
            .first { calendar.isDate($0.observedAt, inSameDayAs: dayStart) }?
            .value ?? 0
        return TrendDataPoint(date: noon, value: value)
    }
```

**为什么修复有效**：`dailyMetrics` 是日级数据（每天 1 条），可以匹配到当前自然周的 7 天，填到 7 个 cell 中心。

---

## 4. 踩坑清单 / Pitfalls I Fell Into

以下是我在这 4 轮修复过程中犯的推理错误，每条都值得记一笔：

### 4.1 误判 barWidth / clipShape 是元凶

**错在哪**：第一轮看到柱子消失，第一反应是"是不是 barWidth 太大互相覆盖"或"clipShape 圆角裁了柱子"。

**正确思路**：柱子"消失"（不是"被裁"）+ 出现在固定位置（Fri/Sat/Sun）→ 优先怀疑 domain 裁剪，而非视觉样式。

### 4.2 用 `.fixed(width)` 而非 `.ratio()`

**错在哪**：长期用 `.fixed(24)` 手动调柱宽，导致柱子半宽与 domain 延伸量玩猫鼠游戏，屏幕宽度变化时又复现。

**正确思路**：时间序列柱状图优先用 `.ratio(0.6~0.7)`，让柱宽自适应 cell 宽度，结构性消除裁切。

### 4.3 没区分 stride 闭区间 vs 显式 tick 数组

**错在哪**：用 `AxisMarks(values: .stride(by: .day, count: 1))` 期望 7 个 tick，实际得到 8 个（含边界）。

**正确思路**：需要精确控制 tick 数量时，用显式数组 `AxisMarks(values: [Date])`，不要依赖 stride。

### 4.4 把 grid line 和 label 共用同一组 AxisMarks

**错在哪**：grid line 和 label 共用 ticks，导致 grid line 穿过柱子中心，视觉上柱子被"切"成两半。

**正确思路**：grid line 在 cell 边界、label 在 cell 中心，必须用两组独立 `AxisMarks`。

### 4.5 没区分"固定自然周" vs "滚动 7 天"

**错在哪**：Chart 用"自然周 Mon→Sun"，ViewModel 用"今天向前 7 天"，两者错配导致数据点落在 domain 外。

**正确思路**：写代码前先明确"这个窗口的语义是什么"，Chart 和 ViewModel 必须共享同一个 `startOfWeek` 实现。

### 4.6 没区分周聚合数据 vs 日数据

**错在哪**：用 `weeklyMetrics`（周聚合，每周 1 条）去填 7 个日 cell，导致全 0。

**正确思路**：明确数据源语义——`window: .week` 返回的是周聚合，不是日数据。看"本周每天"必须用 `window: .day` 的数据按自然周过滤。

### 4.7 修复时一次只解决一个层面

**错在哪**：第 3 轮 Bug 实际是"视觉层 + 数据层 + 语义层"三层叠加，但每次修复只动一层，导致修了 A 暴露 B。

**正确思路**：复杂 Bug 先分层诊断（视觉 / 数据 / 语义 / 数据源），再决定每层怎么修，避免"打地鼠"。

### 4.8 没有先用 VLM 看截图就猜测根因

**错在哪**：前几轮靠"读代码 + 想象"猜根因，浪费了多轮。

**正确思路**：有截图时，先用 VLM 描述视觉证据（柱子数量、位置、裁切方向、label 列表），再结合代码下结论。

---

## 5. Swift Charts 避坑指南 / Swift Charts Best Practices

### 5.1 Cell 中心原则

柱子放在 cell 中心（如周一 12:00），grid line 放在 cell 边界（如周一 00:00、周二 00:00）。这样柱子永远在两条 grid line 之间，结构性消除裁切。

```swift
// ✅ 数据点在 cell 中心
let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)

// ❌ 数据点在 cell 边界（会被裁）
let dayStart = calendar.startOfDay(for: date)
```

### 5.2 柱宽用 `.ratio()` 而非 `.fixed()`

```swift
// ✅ ratio：柱宽 = cell 宽度 × 0.7，自适应
BarMark(..., width: .ratio(0.7))

// ❌ fixed：固定 24pt，屏幕变化时可能裁切
BarMark(..., width: .fixed(24))
```

### 5.3 Grid line 与 Label 必须分两组 AxisMarks

```swift
// ✅ grid line 在边界，label 在中心
AxisMarks(values: boundaries) { _ in AxisGridLine(...) }
AxisMarks(values: centers) { value in AxisValueLabel(...) }

// ❌ 共用一组，grid line 穿过柱子
AxisMarks(values: .stride(by: .day, count: 1)) { value in
    AxisGridLine(...)
    AxisValueLabel(...)
}
```

### 5.4 Domain 要与数据语义对齐

写代码前先问自己：这个窗口是"固定自然周期"还是"以今天为右端的滚动窗口"？Chart 和 ViewModel 必须用同一个答案。

```swift
// ✅ 共享 startOfWeek
let weekStart = startOfWeek(for: Date())  // Chart 和 ViewModel 都用这个

// ❌ Chart 用 startOfWeek，ViewModel 用 today-6
```

### 5.5 Y 域显式上取整

```swift
// ✅ 显式 Y 域，柱顶永远在顶部 grid line 之下
private var yScaleDomain: ClosedRange<Double> {
    let maxValue = dataPoints.map(\.value).max() ?? 0
    guard maxValue > 0 else { return 0...1 }
    let magnitude = pow(10, floor(log10(maxValue)))
    let niceMax = ceil(maxValue * 1.15 / magnitude) * magnitude
    return 0...niceMax
}
.chartYScale(domain: yScaleDomain)
```

### 5.6 Stride 会产生 N+1 个边界 tick，用显式数组更可控

```swift
// ✅ 显式 7 个 tick
let ticks = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start)! }
AxisMarks(values: ticks)

// ❌ stride 在 7 天 domain 上产生 8 个 tick
AxisMarks(values: .stride(by: .day, count: 1))
```

### 5.7 调试时先用 VLM 看截图再下结论

有截图时，先用 VLM 描述：① 柱子数量 ② 柱子与 label 的对齐关系 ③ 裁切方向 ④ Y 轴范围。再结合代码下结论，避免"读代码 + 想象"的盲猜。

### 5.8 数据源要与窗口语义匹配

| 窗口 | 应该用的数据源 | 原因 |
|---|---|---|
| Day | `hourlyData`（24 小时实时生成） | 需要 24 个小时 cell |
| Week | `dailyMetrics`（日数据）过滤当前自然周 | 需要 7 个日 cell |
| Month | `monthlyMetrics`（月聚合） | 一个月 1 条，够用 |
| Year | `yearlyMetrics`（年聚合） | 一年 1 条，够用 |

---

## 6. 数据流架构建议 / Data Flow Architecture

### 6.1 四窗口数据源约定

针对 `TrendsViewModel`，建议明确以下数据源约定：

| 窗口 | 数据源 | 聚合方式 | Cell 中心 |
|---|---|---|---|
| Day | `hourlyData` | 实时生成 24 点 | `HH:30` |
| Week | `dailyMetrics` | 按当前自然周过滤 7 天 | 每天 `12:00` |
| Month | `monthlyMetrics` | 月聚合，1 条/月 | 当月 15 号 `12:00` |
| Year | `yearlyMetrics` | 年聚合，1 条/年 | 当年 6 月 15 号 `12:00` |

### 6.2 Cell 中心对齐约定

所有窗口的数据点日期都必须对齐到对应 cell 的中心，避免 BarMark 中心落在 cell 边界：

```swift
// Day → HH:30
let centered = calendar.date(byAdding: .minute, value: 30, to: hourStart)

// Week / Month → 每天 12:00
let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)

// Year → 每月 15 号 12:00
let midMonth = calendar.date(byAdding: .day, value: 14, to: monthStart)
let center = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: midMonth)
```

### 6.3 weeklyMetrics 字段清理

`weeklyMetrics` 字段在 `.week` 视图其实用不上（应该用 `dailyMetrics`），建议：

- **方案 A（保守）**：保留字段备用，但 `.week` 视图改用 `dailyMetrics`。
- **方案 B（激进）**：删除 `weeklyMetrics` 字段和对应的 `metricRepo.fetch(... window: .week)` 调用，减少混淆。

### 6.4 共享 startOfWeek 实现

`TrendChart.startOfWeek` 和 `TrendsViewModel` 内部的 `startOfWeek` 必须用同一个实现，避免 `firstWeekday` 不一致：

```swift
// 建议抽到一个共享扩展
extension Calendar {
    func startOfWeek(_ date: Date) -> Date {
        var cal = self
        cal.firstWeekday = 2  // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }
}
```

### 6.5 增加单元测试覆盖边界日期

建议增加以下测试用例：

- **跨周边界**：今天分别是周一、周三、周日时，`.week` 视图数据是否正确
- **跨月边界**：今天分别是 1 号、15 号、月末时，`.month` 视图数据是否正确
- **跨年边界**：今天分别是 1 月 1 日、6 月 15 日、12 月 31 日时，`.year` 视图数据是否正确
- **时区边界**：UTC 23:30 和 UTC 00:30 时，聚合桶是否落在正确的本地日

---

## 7. 未来 Checklist / Future Checklist

新增任何时间序列图表时，请逐条自检：

- [ ] 1. 柱子是否在 cell 中心（而非 cell 边界）？
- [ ] 2. 柱宽是否用 `.ratio()` 而非 `.fixed()`？
- [ ] 3. Grid line 与 Label 是否分成两组独立 `AxisMarks`？
- [ ] 4. Domain 是否与数据语义对齐（自然周 vs 滚动 7 天）？
- [ ] 5. Y 域是否显式上取整 + 留白（避免柱顶超顶部 grid line）？
- [ ] 6. 边界 tick 是否避免重复（用显式数组而非 stride）？
- [ ] 7. 数据源是否与窗口语义匹配（Week 用日数据，不是周聚合）？
- [ ] 8. Chart 与 ViewModel 是否共享同一个 `startOfWeek` 实现？
- [ ] 9. 是否覆盖跨周期边界日期的单元测试（周一/周日/月初/月末/年初/年末）？
- [ ] 10. 是否用 VLM 验证过视觉结果（柱子数量、对齐、裁切方向）？

---

## 附录：核心修复对照表

| Bug | 错误做法 | 正确做法 |
|---|---|---|
| Domain 静默裁剪 | 自然周 domain + 滚动 7 天数据 | Domain 与数据语义对齐 |
| 时区偏移 | 直接用 `aggregate` 的桶日期 | 按本地日重新对齐 |
| BarMark 中心在边界 | `.fixed(24)` + 数据点在 Mon 00:00 | `.ratio(0.7)` + 数据点在 Mon 12:00 |
| Stride 多 tick | `.stride(by: .day, count: 1)` | 显式 `(0..<7).map { ... }` |
| Grid line 穿柱 | grid line 与 label 共用 ticks | 两组独立 `AxisMarks` |
| 数据源错配 | `weeklyMetrics`（周聚合）填 7 个日 cell | `dailyMetrics`（日数据）按自然周过滤 |

---

**报告完。** 如需进一步细化某个章节或补充单元测试代码示例，请告知。

---

# Part Two — Sigma 迭代：Charts 渲染崩溃与混合架构演进

> **日期**：2026-07-01 · **涉及轮次**：6 轮迭代 · **核心问题**：Charts 内部断言崩溃、窗口交叉污染、坐标系统不一致

---

## 8. 背景 / Background

在完成 Gamma-2 迭代（LineMark → BarMark 迁移、4 窗口支持）后，柱状图在 iOS 27 / Xcode 26 beta 环境中暴露出系统性的渲染问题。本部分记录从"修补 Charts 参数"到"分离式混合架构"的完整演进过程。

### 8.1 触发条件

原有的 Charts 配置（`unit:` + `.ratio()` + `range: .plotDimension(padding: 0)`）在 iOS 27 beta 中可正常渲染，但存在柱子溢出域边界、首尾柱被裁切、Grid line 与柱子不对齐等视觉问题。任何试图修复这些问题的 API 参数调整都会触发 `ChartInternal.swift:170` 内部断言崩溃。

---

## 9. 核心 Bug #1：Charts API 三元组不可拆分

### 9.1 现象

尝试以下任一修改均导致即时崩溃（SIGTRAP）：

| 尝试的修改 | 错误信息 |
|-----------|---------|
| 添加 `type: .category` 到 `chartXScale` | `scale type is incompatible with data values` |
| 移除 `unit:` 参数 | 同上（内部断言） |
| `.ratio()` → `.automatic` | 同上（内部断言） |
| 移除 `range: .plotDimension(padding: 0)` | 同上（内部断言） |
| 使用 `RuleMark` + `category` scale | `Double` 值与 category scale 类型冲突 |

### 9.2 根因

在 iOS 27 / Xcode 26 beta 的 Swift Charts 实现中，`unit:` + `.ratio()` + `range: .plotDimension(padding: 0)` 构成了一个**不可拆分的 API 契约三元组**：

```
BarMark(x:unit:) + width:ratio() + chartXScale(range:plotDimension(padding:0))
     ↑                    ↑                        ↑
  三者缺一不可，拆分任意一个 → ChartInternal.swift:170 断言失败
```

这是 iOS 27 beta 的 Swift Charts 内部实现限制，不是标准的 Swift Charts API 行为。推测 beta 版本的 Charts 在处理 BarMark 布局时，对这三个参数的组合有硬编码的预检查逻辑。

### 9.3 结论

**在当前 beta 环境（iOS 27 + Xcode 26）下，无法通过调参修复 Charts 的溢出/对齐问题**。任何参数调整都会触发崩溃，只能保持原有"能渲染但不完美"的配置，或绕过 Charts 框架。

---

## 10. 核心 Bug #2：四窗口共享配置导致的交叉污染

### 10.1 现象

```
修复 Day → Week 溢出  →  Month 网格线错位
修复 Month → 调 ratio →  Year 柱子变宽
修复 Year  → 改 domain →  Day 标签消失
```

每次修复一个窗口的问题，都会在其他窗口制造新问题。

### 10.2 根因

四个窗口（Day / Week / Month / Year）共享同一个 `BarMark` 配置块和一个 `chartXScale(range:)` 配置。但四个窗口的数据特征完全不同：

| 窗口 | 数据点数 | 数据间隔 | `unit:` | 适用策略 |
|------|---------|---------|---------|---------|
| Day | 24 | 均匀 (1h) | `.hour` | ratio 工作正常 |
| Week | 7 | 均匀 (1d) | `.day` | `unit:` 偏移导致溢出 |
| Month | 28-31 | 均匀 (1d) | `.day` | ratio 工作正常 |
| Year | 12 | 不均匀 (28-31d) | `.month` | 月份长度差异导致对齐偏差 |

共享的 `width: .ratio()` 在各窗口语义不同：
- Day: `0.6 * 1 hour cell` ✓
- Week: `0.7 * 1 day cell` → `unit: .day` 偏移半格 → ✗ 首尾溢出
- Month: `0.6 * 1 day cell` ✓（数据充足时）
- Year: `0.65 * ~30 day cell` → 视觉过宽

### 10.3 解决方案：分离式设计

将 `TrendChart` 重构为**四个独立实现的汇聚点**：

```swift
struct TrendChart {
    var body: some View {
        switch timeWindow {
        case .day:   dayChart     // Charts: BarMark(unit: .hour,  ratio: 0.6)
        case .week:  weekChart    // Pure SwiftUI: HStack + Path grid
        case .month: monthChart   // Charts: BarMark(unit: .day,   ratio: 0.6)
        case .year:  yearChart    // Charts: BarMark(unit: .month, ratio: 0.65)
        }
    }
}
```

每个窗口拥有独立的 `Chart`（或 SwiftUI view）、独立的 `BarMark` 配置、独立的 domain 和 `AxisMarks`。共享的只有 Y 轴、渐变色和卡片 UI。

---

## 11. 核心 Bug #3：Week 视图的 Charts 不可用

### 11.1 现象

Week 视图（7 天）在 Charts 中始终存在柱子溢出的问题。尝试过的修复：

| 尝试 | 参数 | 结果 |
|------|------|------|
| A | 保持 `ratio: 0.7` + `padding: 0` | 首尾柱被裁 |
| B | `ratio: 0.5` + `padding: 0` | 仍溢出 |
| C | `ratio: 0.5` + `startPadding: 0.25, endPadding: 0.25` | 仍然溢出 |
| D | 扩展 domain ±12h + `ratio: 0.5` + `padding: 0` | 仍然溢出 |

### 11.2 根因

Week 窗口是唯一一个被 `unit: .day` 的偏移效应严重影响的窗口。具体原因：

```
柱子设计位置: 每天 12:00 (noon, cell 中心)
unit: .day 效果: Charts 把柱子挪到 day-unit 的"中部" → 实际偏移 0.5 天
偏移后: 周一柱子从 Mon 12:00 移到 Mon 00:00 ~ Tue 00:00 中间某处
       周日柱子同理右移 → 首尾溢出域边界

Day 视图不受影响: 24 个 cell 密集，unit: .hour 偏移仅 0.5h，margin 足够
Month 视图不受影响: 数据充足时 cell 宽度小 (1/30)，0.5 day 偏移被吸收
Year 视图不受影响: unit: .month 偏移 0.5 月，但只有 12 根柱子，域足够宽
```

### 11.3 解决方案：纯 SwiftUI Week 视图

Week 是最简单的窗口（7 个等宽 cell），用纯 SwiftUI 实现零风险：

```
HStack(alignment: .bottom, spacing: 0) {
    7 个 VStack { Spacer(); Rectangle() }  // 底部对齐
}
+ ZStack overlay: Path 水平 4 条虚线 + 垂直 8 条虚线
+ Y 轴标签 VStack
+ X 轴星期缩写 HStack
```

**关键优势**：
- 7 天等宽，无日历日期计算
- 无 Charts API 依赖 → 零崩溃风险
- `maxWidth: .infinity` 自动均分，无需 ratio 计算
- Grid line 用 Path 精确控制，不依赖 AxisMarks

---

## 12. 核心技术决策 / Key Technical Decisions

### 12.1 混合架构

```
TrendChart
├── Day   → Charts (BarMark)      ← Charts 在此窗口正常工作
├── Week  → Pure SwiftUI          ← Charts 在 Week 窗口有 bug，切换方案
├── Month → Charts (BarMark)      ← Charts 在此窗口正常工作
└── Year  → Charts (BarMark)      ← Charts 在此窗口正常工作
```

**原则**：不为框架 bug 牺牲整个页面的一致性。哪个窗口在 Charts 下工作正常，就保留 Charts；哪个窗口有问题，就切换到纯 SwiftUI。外层卡片 UI 保持统一。

### 12.2 分离式数据流

```
TrendsViewModel.chartData(for:)
    → Day:   hourlyData[type]     (24 点，实时生成)
    → Week:  dailyMetrics → 自然周 7 点
    → Month: monthlyMetrics → 月内所有点
    → Year:  yearlyMetrics → 12 点
         ↓
TrendChart (dispatcher)
    → dayChart   ← 独立 Chart + BarMark(.hour)
    → weekChart  ← 独立 SwiftUI (HStack + Path)
    → monthChart ← 独立 Chart + BarMark(.day)
    → yearChart  ← 独立 Chart + BarMark(.month)
```

每个窗口的 ViewModel 数据输出和 View 渲染逻辑完全独立，互不依赖。

### 12.3 诊断方法论

通过本次迭代总结出的高效排查路径：

1. **先定位崩溃层**：是 Charts 内部（断言/崩溃）还是布局层（对齐/溢出）？
2. **再判断窗口独立性**：修改一个窗口是否影响其他窗口？→ 说明耦合需要分离
3. **最后选择策略**：Charts 能工作 → 保持 Charts；Charts 有问题 → 纯 SwiftUI

---

## 13. 经验教训 / Lessons Learned

### 13.1 Beta 框架的防御性编程

iOS 27 beta 的 Swift Charts 存在未文档化的内部约束。当框架行为不符合预期时：

1. **不要假设 API 是正交的** — `unit:` + `.ratio()` + `range:` 可能在内部耦合
2. **保存能工作的"基线配置"** — 用 git tag 标记最后一个可渲染版本
3. **遇到断言 → 立即换方案** — 不要在内部断言上反复调参

### 13.2 分离优于统一

初始设计倾向"一套配置适配所有窗口"。但实际上四个窗口的数据特征差异太大：

- Day/Week: 等间距数据，适合 ratio + HStack
- Month/Year: 日历依赖的数据，需要 date-fraction 定位

**分离式设计虽然代码量更多，但能消除交叉污染，长期维护成本更低。**

### 13.3 纯 SwiftUI 作为逃生舱

当系统框架（Charts）表现不稳定时，完全有能力用纯 SwiftUI 独立实现图表。关键是保持视觉一致性：

| 元素 | Charts 版本 | 纯 SwiftUI 版本 |
|------|------------|----------------|
| 柱子 | BarMark + LinearGradient | Rectangle + LinearGradient |
| 水平网格 | AxisMarks + AxisGridLine | Path + StrokeStyle |
| 垂直网格 | AxisMarks + AxisGridLine | Path + StrokeStyle |
| X 轴标签 | AxisMarks + AxisValueLabel | Text + position |
| Y 轴标签 | AxisMarks + AxisValueLabel | VStack + Text |

---

## 14. 最终架构总结

```
Follower/Features/Shared/TrendChart.swift
├── struct TrendChart (dispatcher)
│   ├── dayChart    → import Charts, BarMark(unit: .hour)
│   ├── weekChart   → import SwiftUI, HStack + Path (0 Charts dependency)
│   ├── monthChart  → import Charts, BarMark(unit: .day)
│   ├── yearChart   → import Charts, BarMark(unit: .month)
│   ├── sharedYAxis → @AxisContentBuilder (Charts Y axis shared)
│   ├── formatY()   → 智能格式化 (1.2k, 3.4k)
│   └── emptyState  → 通用空状态
└── #Preview × 4    → Day / Week / Month / Year 独立预览
```

**关键指标**：
- 崩溃风险：仅 Week 窗口零 Charts 依赖，Day/Month/Year 使用已验证可渲染的 Charts 配置
- 交叉污染：零 — 每个窗口独立实现
- 可维护性：修改单个窗口只需改动其对应方法，不影响其他窗口
- 预览覆盖：4 个独立 Preview，开发时可同时对比

---

**报告完。**
