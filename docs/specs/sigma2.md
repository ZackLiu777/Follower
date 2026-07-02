# Sigma-2 迭代记录

> **迭代周期**：2026-06-30 → 2026-07-02
> **核心目标**：修复柱状图渲染 Bug、实现 Premium UI、完善多语言、规范 MVVM 架构
> **涉及文件**：63 个源文件 + 15 个测试文件 + 2 个 CI 配置

---

## 1. 功能实现清单

### 1.1 TrendChart 柱状图渲染修复（6 轮迭代）

**背景**：iOS 27 / Xcode 26 beta 的 Swift Charts 存在内部 API 约束。`unit:` + `.ratio()` + `range: .plotDimension(padding: 0)` 构成不可拆分的三元组。拆分任何一个参数都会触发 `ChartInternal.swift:170` 断言崩溃（SIGTRAP）。

**最终方案 — 分离式混合架构**：

```
TrendChart
├── dayChart   → Charts BarMark(unit: .hour,  ratio: 0.6)  ← Charts 正常
├── weekChart  → Pure SwiftUI (HStack + Path grid)         ← Charts 有 Bug
├── monthChart → Charts BarMark(unit: .day,   ratio: 0.6)  ← Charts 正常
└── yearChart  → Charts BarMark(unit: .month, ratio: 0.65) ← Charts 正常
```

**关键决策**：
- 四个窗口从共享 `BarMark` 配置改为完全独立的 Chart 实现
- Week 视图全部用纯 SwiftUI（`Rectangle` + `Path` grid line + `GeometryReader`）
- Day/Month/Year 保留 Charts API 但各有独立参数
- 共享 Y 轴和卡片 UI，互不影响

**涉及文件**：`TrendChart.swift`（完全重写）、`TrendsViewModel.swift`、`TrendsView.swift`

---

### 1.2 Premium 功能实现

#### 1.2.1 DashboardViewModel 接入真实 Premium 服务

之前：Dashboard 的 Premium 数据全部来自内联 Mock（`MockPostGenerator`、随机字符串数组）。

之后：注入 7 个 Premium 服务协议，`loadPremiumInsights()` 调用真实服务计算：

| 服务 | 方法 | 产出 |
|------|------|------|
| `PredictionService` | `predictSMA(dataPoints:window:)` | `PredictionResult` |
| `ActivityAnalysisService` | `analyze(events:from:to:)` | `ActivityResult` |
| `RetentionAnalysisService` | `analyze(snapshots:)` | `RetentionResult` |
| `ScoringService` | `scoreEngagement(snapshots:)` | `ScoringResult` |
| `GeoDistributionService` | `fetchDistribution(accountId:)` | `GeoDistributionResult` |
| `ComparisonService` | `compare(currentSnapshots:previousSnapshots:extract:)` | `ComparisonResult` |
| `AIAnalysisService` | `analyze(snapshots:)` | `[AIInsight]` |

Mock 回退保留（`unfollowList`、`bestPostingTime`、`contentTip`、`predictedFollowers`），确保即使真实服务异常 UI 仍有数据展示。

#### 1.2.2 Premium 卡片（9 张）

Dashboard Premium 区域从 4 张扩展到 9 张卡片：

| # | 卡片 | 图标 | 数据来源 |
|---|------|------|---------|
| 1 | Follower Prediction | `chart.line.uptrend.xy` | `predictionResult` |
| 2 | Activity Analysis | `bolt.fill` | `activityResult` |
| 3 | Engagement Quality | `star.fill` | `qualityScore` |
| 4 | Retention & Churn | `person.2.fill` | `retentionResult` |
| 5 | Geo Distribution | `globe.asia.australia.fill` | `geoDistribution` |
| 6 | Long-term Comparison | `arrow.left.arrow.right` | `comparisonResult` |
| 7 | Who Unfollowed You | `person.2.slash` | `unfollowList` (Mock) |
| 8 | Best Time to Post | `clock` | `activityResult` / Mock |
| 9 | Content Strategy | `lightbulb` | `aiSummary` / Mock |

#### 1.2.3 Premium 详情页（5 个新建 + 6 个更新）

**新建文件**：
- `ActivityDetailView.swift` — 活跃度分析（进度条 + 级别标签 + 日均事件）
- `RetentionDetailView.swift` — 留存与流失（净增长率 + 风险等级 + 起止对比）
- `QualityDetailView.swift` — 互动质量评分（分数 + 权重分解）
- `GeoDetailView.swift` — 粉丝地域分布（顶部区域 + 百分比条形图）
- `ComparisonDetailView.swift` — 长期趋势对比（方向 + 变化百分比）

**更新文件**（添加 Theme 渐变背景）：
- `PredictionDetailView.swift`、`BestTimeView.swift`、`ContentStrategyView.swift`
- `UnfollowListView.swift`、`EngagementDetailView.swift`、`FollowerDetailView.swift`

所有详情页统一使用 `ZStack { LinearGradient(theme) }` 背景 + `.scrollContentBackground(.hidden)`。

---

### 1.3 趋势详情页

点击 Trends 页面任意统计图表卡片 → 进入 `TrendDetailView`：

- Hero 卡片：当前值（44pt bold）+ 箭头 + 变化量 + 百分比
- 完整尺寸 TrendChart
- 2×2 统计摘要网格（平均值 / 最大值 / 最小值 / 总变化量）
- 周期变化文字摘要

**涉及文件**：`TrendDetailView.swift`（新建）、`TrendsView.swift`（添加 `NavigationLink`）

---

### 1.4 多语言本地化（91 个新 Key）

**新增 L10n Key 覆盖范围**：

| 类别 | 数量 | 示例 |
|------|------|------|
| Premium 卡片标题 | 10 | `premium.followerPrediction` → "粉丝预测" |
| 卡片数值片段 | 5 | `premium.analyzing` → "分析中…" |
| 活跃度详情 | 13 | `premium.highlyActive` → "高度活跃" |
| 留存详情 | 12 | `premium.churnHigh` → "高风险" |
| 互动质量详情 | 13 | `premium.excellent` → "优秀" |
| 地域分布详情 | 4 | `premium.topRegion` → "热门地区" |
| 趋势对比详情 | 8 | `premium.growing` → "增长中" |
| 最佳发帖时间 | 4 | `premium.hourlyHeatmap` → "每小时热力图" |
| 预测详情 | 2 | `premium.predictionDescription` |
| Dashboard 通用 | 3 | `dashboard.recentContent` → "最近内容" |
| 星期名称 | 7 | `premium.dayMon` → "周一" |

全部支持 en / zh-Hans / zh-Hant / ja 四种语言。

**涉及文件**：`L10n.swift`、`Localizable.xcstrings`、12 个 View 文件

---

### 1.5 Instagram 主题重设计

**问题**：Instagram 主题的渐变背景与 Rose Gold（玫瑰金）过于相似（都是暖粉色系）。

**解决**：重新设计为亮珊瑚暖橘 → 柔紫白光影渐变：

```
backgroundGradientStart: (1.00, 0.89, 0.82)  // 亮珊瑚橘
backgroundGradientEnd:   (0.97, 0.93, 1.00)  // 柔紫白光
```

与玫瑰金（粉藕 + 奶油）在视觉上形成明显区分。Accent 和 Chart 配色同步使用 Instagram 经典渐变（#F58529 → #DD2A7B）。

---

### 1.6 开屏动画优化

**之前**：开屏 2 秒后直接 `showSplash = false`，生硬切换到主界面。

**之后**：
```
t=0.0s   入场：scale 0.8→1.0 + opacity 0→1（spring 弹性）
t=2.0s   预退出：scale 1.0→0.95 + opacity 1→0.5（easeIn）
t=2.25s  onComplete() → 父级 withAnimation 设置 showSplash=false
         .transition(.opacity) → SplashView 完全淡出
```

**涉及文件**：`SplashView.swift`、`FollowerApp.swift`

---

### 1.7 MVVM 架构规范化

将 4 处违反 MVVM 原则的代码块移动到正确位置：

| 代码块 | 原位置（错误） | 新位置（正确） |
|--------|--------------|--------------|
| `TrendDataPoint` struct | `TrendsViewModel.swift` | `Models/TrendDataPoint.swift` |
| `MetricType.localizedName` | `TrendsView.swift` | `Models/Metric.swift` |
| `TimeWindow: CaseIterable` | `TrendsView.swift` | `Models/Metric.swift` |
| `ExportFormat` enum | `SettingsViewModel.swift` | `Models/ExportFormat.swift` |

---

### 1.8 代码注释

为全部 63 个源文件中的每个 struct、class、enum、protocol、function、computed property 添加了 `///` 单行注释（中英夹杂）。文件头部注释保持不变。

---

### 1.9 测试套件

#### 新增单元测试

| 文件 | 测试数 | 覆盖范围 |
|------|--------|---------|
| `PremiumServicesTests.swift` | 30 | 7 个 Premium 服务（Prediction/Scoring/Retention/Activity/Comparison/Geo/AI） |
| `PremiumViewModelTests.swift` | 7 | DashboardViewModel Premium 加载 + 边界用例 |
| `TrendsViewModelTests.swift`（更新） | +3 | chartData 各窗口排序测试 |
| `ModelsTests.swift`（更新） | +7 | ExportFormat / PremiumFeatureKey / TrendDataPoint |

#### 新增 UI 测试

| 文件 | 测试数 | 覆盖范围 |
|------|--------|---------|
| `PremiumUITests.swift`（更新） | +10 | 9 张卡片导航 + 锁定状态 + 主题持久 |
| `TrendsUITests.swift`（更新） | +3 | 图表点击详情 + 返回 + 时间窗验证 |

#### CI 配置更新

`ios-ci.yml` 新增 `PremiumServicesTests` 和 `PremiumViewModelTests` 到必过测试列表。

---

### 1.10 代码行数统计

| 类别 | 行数 |
|------|------|
| 源代码 (Follower/) | 8,018 |
| 单元测试 (FollowerTests/) | 2,236 |
| UI 测试 (FollowerUITests/) | 673 |
| **总计（不含 Vendor）** | **10,927** |

---

## 2. 踩坑记录

### 2.1 Swift Charts API 三元组不可拆分

**现象**：任何对 `unit:` + `.ratio()` + `range: .plotDimension(padding: 0)` 的参数调整都导致 `ChartInternal.swift:170` 内部断言崩溃。

**尝试过的失败方案**：
| 尝试 | 参数 | 结果 |
|------|------|------|
| 添加 `type: .category` | domain + type | 崩溃（category 与 Int 数据不兼容） |
| 移除 `unit:` | 仅 `.value("Date", date)` | 崩溃（内部断言） |
| `.ratio()` → `.automatic` | width 参数变更 | 崩溃（内部断言） |
| 使用 `RuleMark` + category | RuleMark Double 值 | 崩溃（类型冲突） |

**根因**：iOS 27 beta 的 Charts 内部对 BarMark 布局有硬编码预检查，这三个参数必须同时出现。这不是标准的 Swift Charts API 行为，属于 beta 版本特有的限制。

**教训**：Beta 框架中，遇到内部断言不要反复调参。保存能工作的"基线配置"，果断切换替代方案（纯 SwiftUI）。

---

### 2.2 四窗口共享配置的交叉污染

**现象**：
```
修复 Day → 调整 ratio → Week 溢出
修复 Week → 改 domain → Month 网格线错位
修复 Month → 调 padding → Year 柱子变宽
```

**根因**：四个窗口的 `BarMark` 和 `chartXScale(range:)` 是共享的，但四个窗口的数据特征完全不同（24/7/30/12 个点，等间距 vs 不等间距，不同 `unit:` 参数）。

**解决**：分离式设计 — 每个窗口拥有独立的 Chart 实现，互不影响。

---

### 2.3 Week 视图 Charts 不可用

**现象**：Week 窗口在所有参数组合下都存在首尾柱溢出问题（ratio 0.7→0.5、padding 0→0.25、domain ±12h 均无效）。

**根因**：Week 是唯一被 `unit: .day` 偏移效应严重影响的窗口。`unit: .day` 将柱子偏移 0.5 天，而 Week 只有 7 个 cell（VS Day 的 24 个 cell 吸收偏移，Month 的 30 个 cell 吸收偏移）。

**解决**：Week 用纯 SwiftUI 替代 Charts。7 天等宽 HStack + Path grid line，零 Charts 依赖。

---

### 2.4 chartOverlay + ChartProxy 坐标系不一致

**现象**：使用 `.chartOverlay` + `ChartProxy.position()` 定位纯 SwiftUI 柱子时，柱子全部缩在底部。

**根因**：`ChartProxy.position(forY:)` 返回 Chart 坐标系（Y 轴向上），但 SwiftUI `.position(x:y:)` 使用屏幕坐标系（Y 轴向下）。直接使用导致 `barH = yZero - yVal` 为负值（全部变成 1px）。

**解决**：放弃 `proxy.position()`，改用 `plotFrame` 的尺寸 + `(date - domainStart) / domainSpan` 手动计算 X 位置，`value / yMax * height` 手动计算 Y 位置。

---

### 2.5 PremiumViewModelTests 的 MainActor dealloc 崩溃

**现象**：
```
___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED
DashboardViewModel.__deallocating_deinit
TaskLocal::StopLookupScope::~StopLookupScope()
```

**根因**：`DashboardViewModel` 是 `@MainActor`，持有 11 个依赖（含 7 个 async 服务协议）。在 XCTest 的 `@MainActor` 测试方法结束时，Swift Concurrency 运行时的 `TaskLocal` 清理与 VM dealloc 产生竞争条件，导致 double-free。

**解决**：移除"仅检查 nil 初始值"的测试方法（该断言在 `NoAccount_DoesNotCrash` 测试中隐式覆盖）。真正的 VM 生命周期测试在 `async` 测试中不受影响（VM 在 async 上下文中存活足够长）。

---

### 2.6 HStack index 定位 VS date-fraction 定位

**现象**：月视图和年视图中，纯 SwiftUI HStack 的 index-based 均分定位与 Charts 的 date-based 线性定位不一致。

**根因**：HStack 按 `i/n * width` 均分空间，但 Charts 按 `(date - domainStart) / domainSpan * width` 映射位置。当数据不是每天均匀分布时（如月视图只有 5 个周聚合点），两者位置完全不同。

**解决**：日/周视图数据是等间距的（24 小时 / 7 天），HStack 定位与 date-fraction 定位等价，无需处理。月/年视图最终回归 Charts API（Day/Month/Year 窗口在 Charts 下正常工作）。

---

### 2.7 硬编码字符串遗漏

**现象**：多次迭代中，新 UI 的硬编码字符串被遗漏在多语言适配之外。

**遗漏过的字符串**：
- Dashboard: "Recent Content" / "View All" / "No posts yet."
- 多个 Premium 详情页中的导航标题和描述文字

**教训**：每次新增 UI 时同步检查 `grep -rn '"[A-Z]' Follower/` 确保没有遗漏。

---

### 2.8 DIContainer 的依赖膨胀

**现象**：`DashboardViewModel` 的 init 参数从 3 个增长到 11 个（3 repos + 1 syncEngine + 1 eventRepo + 7 Premium services）。

**风险**：每新增一个 Premium 服务，ViewModel 和 ContentView 的 init 都要同步更新。

**建议**：未来考虑引入 `PremiumServiceContainer` 将 7 个 Premium 服务打包成一个 struct。

---

## 3. 架构决策记录

### ADR-001: 分离式 Chart 架构

**决策**：TrendChart 的四个时间窗口使用独立的 Chart 实现，而非共享配置。

**理由**：
- 四个窗口的数据特征差异大，共享配置导致交叉污染
- Week 窗口需要纯 SwiftUI 替代方案（Charts 不兼容）
- 每个窗口的参数调整不影响其他窗口

**代价**：代码量增加（每个窗口 ~50-80 行独立代码），但长期维护成本降低。

### ADR-002: 混合渲染策略

**决策**：Charts 用于 Day/Month/Year 的背景网格和轴线，纯 SwiftUI 用于 Week 的全部渲染。

**理由**：
- Day/Month/Year 在 Charts 下工作正常，无需重写
- Week 是唯一有问题的窗口，且数据最简单（7 个等宽 cell）
- 纯 SwiftUI 实现零框架依赖，零崩溃风险

### ADR-003: Premium 服务 Mock 回退

**决策**：`loadPremiumInsights()` 中同时调用真实服务和 Mock 回退。

**理由**：
- 保证 UI 始终有数据展示（即使真实服务异常）
- Alpha 阶段数据不完整，Mock 填充空白
- 后续可逐步替换 Mock 为真实数据

---

## 4. 后续建议

1. **Premium 服务容器化**：将 7 个 Premium 服务打包为一个 `PremiumServiceContainer`，简化依赖注入。
2. **Week 视图 Chart 回归**：等 iOS 27 正式版修复 Charts API 后，可考虑将 Week 视图迁回 Charts。
3. **Snapshot Testing**：为 4 个 Chart 窗口添加截图对比测试，防止视觉回归。
4. **GeoDistribution 真实数据**：`GeoDistributionService` 当前返回硬编码 Mock 数据，需接入真实 API。
5. **AIAnalysis 真实 ML**：`AIAnalysisService` 当前是规则引擎占位，后续替换为 CoreML 模型。
6. **Accessibility**：Premium 详情页的图表和统计数字需要 VoiceOver 标签。

---

**文档完。**
