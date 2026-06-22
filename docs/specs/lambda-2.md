# Lambda-2 踩坑记录

> 记录本次迭代中背景同步、图表统计、Liquid Glass 三大核心问题，以及错误路径与正确方案。

---

## 1. 背景随主题同步

### 踩坑历程

**错误 1**：只在 `FollowerApp` 根层级加 `.background(theme.backgroundPrimary)`，期望子页面透明穿透。

- 为什么失败：`NavigationStack`、`ScrollView`、`Form` 各自有系统不透明背景层，覆盖了全局背景。

**错误 2**：加 `.scrollContentBackground(.hidden)` 移除系统背景，但没有补充替代背景。

- 为什么失败：移除了系统 `UITableView` / `UICollectionView` 的 background rendering layer，View 变成透明，露出 `UIWindow` 默认色（灰白），主题切换无变化。

**错误 3**：在 `FollowerApp` 加 `ZStack { LinearGradient + ContentView }`，以为渐变能穿透。

- 为什么失败：每个页面的 `NavigationStack` 仍然是独立渲染上下文，子页面看不到父级 ZStack 的渐变层。

### 正确方案

**每页独立注入 ZStack 渐变背景**：

```swift
NavigationStack {
    ZStack {
        LinearGradient(theme.backgroundGradientStart → theme.backgroundGradientEnd)
            .ignoresSafeArea()
        ScrollView / Form { ... }
            .scrollContentBackground(.hidden)
    }
}
```

**SettingsView 行背景**：`Form` Section 的卡片背景是 UIKit `UITableViewCell` 控制的，SwiftUI 的 `.background()` 不改它。必须用 `.listRowBackground(theme.cardSurface)` 显式覆盖每一行。

**颜色方案**：删除 `AppState.colorScheme` 和 Settings 中的 System/Light/Dark Picker。改为 `FollowerApp` 中 `.preferredColorScheme(theme.isDark ? .dark : .light)`，由 `isDark` 自动驱动。

**cardSurface 与背景同色**：浅色主题的 `cardSurface` 设为 `backgroundGradientStart.opacity(0.5~0.7)`，卡片融入背景但保留层级感。

---

## 2. 趋势条形统计图

### 踩坑历程

**错误 1 — BarMark 宽度用 `.ratio()` 或 `.automatic`**：Swift Charts 在 Xcode 26 beta 中 `BarMark` 不渲染（轴正常但无柱）。`.automatic` 宽度在此 beta 中行为异常。

- 正确：用 `.fixed(CGFloat)` 根据数据量自适应（≤7条=24pt, 8-20条=18pt, 21-50条=14pt, 50+条=10pt）。

**错误 2 — X 轴用 `.stride(by: .weekOfYear)`**：`weekOfYear` 可能落在无数据日期，标签与实际数据点不对齐。

- 正确：从真实数据点抽样生成 `xAxisDates`。≤7条=全部显示, 8-20条=每3个取1, 21-50条=每7个取1, 50+条=每14个取1。

**错误 3 — 点赞/评论/分享/浏览图表无数据**：

根因在 `AggregationService.buildSnapshots()` 两层 bug：

1. **Tuple 整体覆盖**：`grouped[day] = (新值, 旧值, ...)` 每次事件覆盖整个 tuple。`followerChange` 事件保留 `current.likes/comments/shares/views`（初始值 0），覆盖了 `profileSnapshot` 已设置的 300/50/20/5000。

2. **事件未排序**：`eventRepo.fetch()` 不保证 `observedAt` 顺序。`followerChange` 可能先于 `profileSnapshot` 执行。

**正确修复**：

```swift
// 1. 先排序
let sorted = events.sorted { $0.observedAt < $1.observedAt }

// 2. 逐字段修改（不覆盖整 tuple）
var cur = grouped[day] ?? (0,0,0,0,0,0,0,0,0)
cur.followers = point.followersCount  // 只改相关字段
// likes/comments/shares/views NOT touched by followerChange
cur.count += 1
grouped[day] = cur
```

**错误 4 — Week/Month 只生成 2 种 MetricType**：`buildMetrics` 的周/月聚合只跟踪了 `followersSum` + `engagementSum`，缺少 `likes/comments/shares/views`。

- 正确：周/月聚合结构从 2 元组扩展为 7 元组 `(fSum, eSum, lSum, cSum, sSum, vSum, count)`，每个窗口生成全部 6 种 MetricType。

**错误 5 — 旧 0 值 Metric 残留**：修改 AggregationService 后，数据库中旧的 0 值 Metric 不会被 upsert 覆盖（如果唯一键匹配失败）。

- 正确：在 `rebuildAll()` 开头调用 `deleteOldMetrics(olderThan: .distantFuture)` 清空重建。

**错误 6 — 趋势数据用 `async let` 在 for 循环内**：Swift 6 中 `async let` 在循环内的行为可能不稳定。

- 正确：改用顺序 `await`（`let d = try await ...`）逐个 fetch。

### 最终 TrendChart 架构

```
TrendChart
├── dataPoints ≤ 12 → 固定宽度 Chart
├── dataPoints > 12 → ScrollView(.horizontal) + 动态 chartWidth
├── BarMark(.fixed(barWidth)) + LinearGradient + clipShape(6) + opacity(0.92)
├── X轴: AxisMarks(values: xAxisDates) — 从真实数据抽样
│       + 虚线网格 StrokeStyle(dash: [4])
│       + 自适应日期格式 (≤7=M/d, 8-30=MMMd, 30+=MMM)
├── .chartXScale(range: .plotDimension(startPadding:20, endPadding:20))
├── .chartPlotStyle { .background(.white.opacity(0.12)) }
└── .background(.regularMaterial) + clipShape(16)
```

---

## 3. Liquid Glass 时间窗选择器

### 踩坑历程

**错误 1 — 手写 Material 模拟**：用 `ZStack { .regularMaterial + .cardSurface + .overlay + .shadow }` 手动搭建。结果只是普通毛玻璃，缺少边缘高光、折射、深度感。

**错误 2 — 每个按钮独立 `.glassEffect()`**：三个按钮各自创建独立玻璃层，看起来像三块玻璃贴在一起，不是一个连续玻璃容器。

**错误 3 — 用 `.background { Capsule().glassEffect() }`**：玻璃画在文字后面，像贴纸。

**错误 4 — 用 `GlassEffectContainer` + `.glassEffectID` + `matchedGeometryEffect` + `DragGesture` 模拟 TabBar 滑块**：Apple 公开 API 没有提供"可拖拽液态胶囊控件"。系统 TabBar 使用的是内部私有实现。

**错误 5 — 添加 `Circle().blur()` 背景装饰层**：这些层干扰 Glass 采样背景，Apple 文档建议"少修饰，让 Glass 自己采样"。

### 正确方案

**原生 `Picker(.segmented)`**：

```swift
Picker("Window", selection: $viewModel.selectedWindow) {
    ForEach(TimeWindow.allCases, id: \.self) { window in
        Text(window.localizedName).tag(window)
    }
}
.pickerStyle(.segmented)
.padding(.horizontal, 24)
```

iOS 26/27 的 `SegmentedPickerStyle` 自带系统级 Liquid Glass 渲染——和底部 TabView 一样，由操作系统自动处理边缘高光、折射和深度，不需要任何自定义 `GlassEffectContainer`、`.glassEffect()`、`.glassEffectID()`。

### 核心原则

| 错误方向 | 正确方向 |
|---------|---------|
| 手写 Material 叠加模拟玻璃 | 信任系统原生控件（Picker/Segmented、TabView） |
| 自定义 `GlassEffectContainer` + 手写 morph 动画 | 系统控件自带玻璃，无需额外 API |
| 给每个按钮独立 `.glassEffect()` | 一个 Picker，系统管理玻璃融合 |
| 添加 `Circle().blur()` 增强折射 | 去掉装饰层，让玻璃自然采样渐变背景 |
| 模拟 TabBar 滑块（`matchedGeometryEffect` + `DragGesture`） | Apple 无公开 drag-slider API，不模拟 |

---

## 4. 其他关键决策

- **6 主题**：Apple Native / Instagram / Apple Dark / Forest / Rose Gold / Mono Stone
- **`isDark` 驱动 `preferredColorScheme`**：删除了 System/Light/Dark Picker
- **页面渐变背景**：`backgroundGradientStart → backgroundGradientEnd`
- **卡片与背景同色**：`cardSurface` 取渐变色的半透明版本
- **TrendsViewModel**：limit-based fetch（`fetch(metricType:window:limit:)`），不用 date-range fetch
- **BarMark `.fixed()` 宽度**：自适应数据量，不用 `.ratio()` / `.automatic`
- **X 轴日期抽样**：从真实数据点采样，不用 `.stride(by:)`
- **AggregationService**：事件排序 + 逐字段修改（非整 tuple 覆盖）+ Week/Month 全 6 种 MetricType + rebuild 清旧数据

---

*2026-06. 基于 Gamma-2 → Lambda-2 实际迭代记录。*
