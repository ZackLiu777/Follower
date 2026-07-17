# Phi: 多账号架构重构 & TrendChart 渲染 Bug 修复

**Branch:** `phi`  
**Date:** 2026-07-17  
**Status:** ✅ Build 通过

---

## 1. 迭代目标

1. 将 Dashboard 粉丝图表与 Trends 页**数据源统一**，使用相同 MetricRepository + 相同计算逻辑
2. 修复 TrendChart **Y 轴渲染 Bug**（全零数据出现负值、小数值标签丢失）
3. 实现**多账号数据隔离**：Dashboard 切换账户 → 全 Tab 同步响应

---

## 2. 修改文件清单

### 2.1 Bug Fix: TrendChart 渲染

| 文件 | 改动 |
|------|------|
| `Follower/Features/Shared/TrendChart.swift` | `yScaleDomain`: 全零数据 `-1...1` → `0...1`；增加 `niceMax <= niceMin` 边界保护 |
| | `formatY`: `0 < value < 1` → 显示 `"%.1f"` 小数，修复前全部显示为 `"0"` |
| | `sharedYAxis`: `value.as(Int.self)` → `value.as(Double.self)` + `formatY`，修复前非整数刻度无标签 |
| | Week chart bar 高度计算：拆分 guard 和 max 逻辑，消除歧义 |
| | 新增 `static func weeklyDataPoints(from:)` 共用方法 |

### 2.2 架构: 数据源统一

| 文件 | 改动 |
|------|------|
| `Follower/Features/Dashboard/DashboardViewModel.swift` | 新增 `metricRepo` 注入；`loadFollowerWeeklyChartData()` 改为调用 `TrendChart.weeklyDataPoints(from:)` |
| `Follower/Features/Trends/TrendsViewModel.swift` | `.week` case 改为调用 `TrendChart.weeklyDataPoints(from:)`；`loadTrends` 内部检测 accountId 变化时自动清空所有缓存 |
| `Follower/ContentView.swift` | 传递 `metricRepo: container.metricRepository` 给 DashboardViewModel |

### 2.3 架构: 多账号全局同步

| 文件 | 改动 |
|------|------|
| `Follower/Core/AppState.swift` | 新增 `selectedAccountId: Int64?` — 全局单例真源 |
| `Follower/Features/Dashboard/DashboardView.swift` | 新增 `onChange(of: viewModel.selectedAccountId)` → 同步到 `appState.selectedAccountId`；移除私有 `AccountBar`，改用 Shared 层 |
| `Follower/Features/Trends/TrendsView.swift` | 新增 `onChange(of: appState.selectedAccountId)` → 触发 `loadTrends`；**撤销**之前误加的 AccountBar |
| `Follower/Features/Shared/AccountBar.swift` | **新建** — 从 DashboardView 提取到 Shared 层的共用组件 |

### 2.4 测试

| 文件 | 改动 |
|------|------|
| `FollowerTests/TrendChartTests.swift` | **新建** — `yScaleDomain`、`formatY`、`weeklyDataPoints`、`sharedYAxis` 各场景测试（16 个） |
| `FollowerTests/AppStateTests.swift` | **新建** — `selectedAccountId` 初始状态、读写、syncState 独立性测试（4 个） |
| `FollowerTests/TrendsViewModelTests.swift` | 新增多账号缓存清空、同账号保留缓存、`weeklyDataPoints` 一致性测试（4 个） |
| `FollowerTests/ServicesTests.swift` | 新增 `averageComments`/`averageShares` per-post 计算、零帖子数、周聚合测试（5 个） |
| `FollowerTests/PremiumViewModelTests.swift` | 新增 `MockMetricRepository`；更新 `makeViewModel` 注入 |
| `FollowerUITests/DashboardUITests.swift` | 新增 Dashboard TrendChart 展示、详情跳转、AccountBar 存在性测试（3 个） |
| `FollowerUITests/TrendsUITests.swift` | 新增 6 指标全展示、Comments/Shares Y 轴验证、多账号切换同步测试（4 个） |

---

## 3. 架构设计

### 3.1 账户选择：AppState 单例真源

```
AppState.selectedAccountId  ← 全局唯一真源
        │
        ├── Dashboard (唯一切换入口)
        │     AccountBar.onSelect(id)
        │       → viewModel.selectAccount(id)
        │       → appState.selectedAccountId = id
        │
        └── Trends (纯响应)
              onChange(of: appState.selectedAccountId)
                → viewModel.loadTrends(accountId: id)
                  → 清空 daily/weekly/monthly/yearly/hourly 缓存
                  → 从 MetricRepository 重新加载
```

### 3.2 数据流：统一图表数据管道

```
TrendChart.weeklyDataPoints(from: dailyMetrics)  ← 唯一计算入口
        │
        ├── DashboardViewModel.loadFollowerWeeklyChartData()
        │     → metricRepo.fetch(.followerGrowth, .day, limit: 90)
        │     → TrendChart.weeklyDataPoints(from:)
        │
        └── TrendsViewModel.chartData(for: .week)
              → dailyMetrics[metricType]
              → TrendChart.weeklyDataPoints(from:)
```

---

## 4. 踩坑记录

### 4.1 ⚠️ `yScaleDomain` 全零数据返回 `-1...1`

**现象**：评论、分享等小数值指标的图表 Y 轴出现 `-2 -1 0 1 2` 等无意义标签。

**根因**：
```swift
guard maxV != 0 || minV != 0 else { return -1...1 }  // Bug
```
全零数据时返回 `-1...1`，Swift Charts 的 `.automatic` 刻度据此生成负值标签。

**修复**：`return 0...1`，并增加 `niceMax <= niceMin` 边界保护：
```swift
guard maxV != 0 || minV != 0 else { return 0...1 }
// ...
if niceMax <= niceMin { niceMax = niceMin + max(1, mag) }
```

### 4.2 ⚠️ `formatY` 丢弃小于 1 的小数值

**现象**：Y 轴出现重复的 `"0"` 标签（如 `1 0 0 0 0`）。

**根因**：
```swift
else if value >= 1 { return String(format: "%.0f", value) }
return "0"  // 0.5, 0.75 全部显示为 "0"
```
`value < 1` 时无条件返回 `"0"`。

**修复**：增加 `0 < value < 1` 分支，显示一位小数：
```swift
else if value > 0 { return String(format: "%.1f", value) }
return "0"
```

### 4.3 ⚠️ `sharedYAxis` 使用 `value.as(Int.self)` 丢失非整数标签

**现象**：Swift Charts（Day/Month/Year 视图）Y 轴刻度只有网格线没有标签。

**根因**：
```swift
if let v = value.as(Int.self) { Text(v, format: .number) }
```
当 Y 轴自动刻度为 0.5、1.5 等非整数时，`as(Int.self)` 返回 nil，标签不渲染。

**修复**：`value.as(Double.self)` + `formatY`：
```swift
if let v = value.as(Double.self) { Text(formatY(v)) }
```

### 4.4 ⚠️ 不要在响应页面加 AccountBar

**错误尝试**：在 TrendsView 中添加 `AccountBar`，让 Trends 页有自己的账户选择器。

**为什么错**：账户切换是**全局行为**，不是在每个 Tab 各自切换。多个 AccountBar 会导致：
- 状态不一致（两个选择器可能不同步）
- 用户在 Dashboard 切了账户，Trends 的 AccountBar 还是旧状态
- 违反单一真源原则

**正确做法**：Dashboard 是唯一切换入口 → 写入 `AppState.selectedAccountId` → 其他 Tab 通过 `onChange` 被动响应。

### 4.5 ⚠️ TrendsViewModel 缓存字典未按 accountId 隔离

**修复前**：
```swift
var dailyMetrics: [MetricType: [Metric]] = [:]  // 不区分账号
```
切换账户调用 `loadTrends(accountId:)` 时只是覆盖字典，但如果忘记在上层先清空，旧账号数据会残留。

**修复后**：`loadTrends` 内部检测 `accountId != selectedAccountId` 时**自动清空全部五个缓存**：
```swift
if accountId != selectedAccountId {
    dailyMetrics = [:]; weeklyMetrics = [:]; monthlyMetrics = [:]
    yearlyMetrics = [:]; hourlyData = [:]
}
selectedAccountId = accountId
```

### 4.6 ⚠️ `averageComments`/`averageShares` 命名误导

**现状**（未在本次修复）：
- Day metric 存储 `Double(snapshot.totalComments)` — 实际是**总数**，不是平均
- Week/Month/Year 存储 `cSum / cnt` — 日均总数，也不是"每帖平均"

**正确语义**：`averageComments` 应为 `totalComments / mediaCount`（每帖平均评论数）。当前 0~2 的值范围对于总数来说太小，对于"每帖平均"来说才是合理的。

**已写入测试** `ServicesTests.swift` 中的 `testAverageCommentsMetricPerPost` 验证了这个语义。

### 4.7 ⚠️ 3σ 异常检测被异常值「自我隐藏」

**现象**：`testAuthenticityDetectsAnomalies` 持续失败，无论怎么调测试数据都无法触发 `hasAnomalies = true`。

**根因**：`AuthenticityService.detectAnomalies` 使用 mean/stdDev 计算 3σ 阈值。极端异常值本身会撑大标准差 σ → 3σ 阈值同步膨胀 → 异常值落在阈值内被「隐藏」。这是经典统计陷阱：只要异常值足够极端，stdDev 一定会跟着变大。

**修复**：改用 **IQR（Tukey's fences）**——基于四分位数 Q1/Q3 而非均值和标准差。Q1/Q3 不受极端值影响，1.5×IQR 围栏始终保持敏感。

```swift
// Before (3σ — broken for outliers)
let mean = deltas.reduce(0, +) / Double(deltas.count)
let stdDev = sqrt(variance)
let threshold = 3 * stdDev  // ← inflated by outliers

// After (IQR / Tukey's fences — robust)
let q1 = sortedDeltas[n / 4]
let q3 = sortedDeltas[3 * n / 4]
let iqr = q3 - q1
let lowerFence = q1 - 1.5 * iqr
let upperFence = q3 + 1.5 * iqr
```

### 4.8 ⚠️ Dashboard 空状态/加载态渐变背景不覆盖全屏

**现象**：创建新账号无数据时，Dashboard 上半部分（含导航栏区域）显示白色，下半部分显示淡蓝渐变。视觉上被切为两半。

**根因**：所有状态的渐变背景通过 `.background(LinearGradient(...))` 附加在内容视图上。`EmptyStateView` 和 `ProgressView` 只有 `minHeight: 300`，渐变仅覆盖内容高度。`NavigationStack` 的导航栏和剩余区域显示系统默认白色。

**修复**：5 个状态分支全部从 `.background()` 改为 `ZStack { LinearGradient(...).ignoresSafeArea() + 内容 }`。`.ignoresSafeArea()` 确保渐变从屏幕顶部（包括导航栏后方安全区域）一直延伸到底部。

### 4.9 ⚠️ 新增 PremiumFeatureKey 后 ModelsTests 硬编码 count 失败

**现象**：`testPremiumFeatureKeyAllCases` 和 `testPremiumFeatureKey_AllCases_NotEmpty` 断言 `count == 13` 失败。

**根因**：Phi 迭代新增 7 个 `PremiumFeatureKey` case（`competitorComparison` / `authenticityAssessment` / `mediaKitExport` / `campaignTracking` / `engagementHeatmap` / `contentScheduling` / `commentManagement`），总数从 13 变为 20。测试中硬编码了旧数值。

**修复**：将 `count == 13` 更新为 `count == 20`。

**教训**：`allCases.count` 测试应使用 `>= N` 而非 `== N`，或者用 `#expect(allCases.contains(.newCase))` 逐个验证，避免每次新增 case 都要更新数值。

### 4.10 ⚠️ 同模块内 Mock 类重复定义

**现象**：`PhiServicesTests.swift` 中定义了 `private final class MockSnapshotRepository` 等 Mock 类，与 `PremiumViewModelTests.swift` 中的同名类冲突，编译报错 `invalid redeclaration`。

**根因**：Swift 中 `private` 在文件作用域等价于 `fileprivate`，两个测试文件在同一模块（`FollowerTests`）中定义同名类导致冲突。

**修复**：从 `PhiServicesTests.swift` 中删除全部 Mock 类定义，复用 `PremiumViewModelTests.swift` 中的 internal Mock 类（同模块可见）。

---

## 5. 测试覆盖

### 单元测试 (61 tests)

| 测试文件 | 数量 | 覆盖 |
|----------|------|------|
| `TrendChartTests` | 17 | `computeYScaleDomain`(7), `formatY`(6), `weeklyDataPoints`(4) |
| `PhiServicesTests` | 23 | `AuthenticityService`(9), `CampaignComparisonService`(5), `EngagementHeatmapService`(7), DashboardVM 集成(2) |
| `AppStateTests` | 4 | 初始 nil, 读写, 重置, syncState 独立性 |
| `TrendsViewModelTests` (新增) | 4 | 切换清缓存, 同账户保留, loadInitialAccount, weeklyDataPoints 一致性 |
| `ServicesTests` (新增) | 5 | averageComments per-post, averageShares per-post, zero mediaCount, 周聚合 |
| `PremiumViewModelTests` (更新) | 3 | MockMetricRepository, Phi PremiumFeatureKey 验证, displayName |
| `ModelsTests` (更新) | — | PremiumFeatureKey.count 20 |

### UI 测试 (7 new tests)

| 测试文件 | 数量 | 覆盖 |
|----------|------|------|
| `DashboardUITests` (新增) | 3 | TrendChart 展示, 详情跳转, AccountBar 存在 |
| `TrendsUITests` (新增) | 4 | 6 指标全展示, Comments Y 轴, Shares Y 轴, 多账号切换同步 |

---

## 6. 后续建议

1. **AggregationService 重构**：将 `averageComments`/`averageShares`/`averageLikes` 的 day metric 改为 `total / mediaCount`，使指标名实相符
2. **Decisions Tab** 同样应通过 `onChange(of: appState.selectedAccountId)` 响应账户切换
3. **TrendChart week chart** 可增加零基线（当存在负值数据时），当前假定所有指标 ≥ 0
4. **formatY** 的 `"%.0f"` 在 Swift 中使用 banker's rounding（1.5 → 2），可考虑显式指定 rounding mode
