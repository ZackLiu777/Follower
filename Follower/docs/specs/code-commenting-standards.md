# Code Commenting Standards

> **项目**：Follower (iOS)
> **版本**：Sigma-2
> **语言**：Swift
> **注释风格**：`///` 文档注释（中英夹杂）

---

## 1. 核心原则

### 1.1 注释回答"为什么"而非"做什么"

```swift
// ❌ 坏 — 重复代码语义
/// 设置 yScaleDomain 为 0...niceMax
private var yScaleDomain: ClosedRange<Double> { ... }

// ✅ 好 — 解释意图和算法选择
/// 自动计算 Y 轴上限，向上取整到美观量级（nice rounding）
private var yScaleDomain: ClosedRange<Double> { ... }
```

### 1.2 公开 API 必须有注释，私有实现可选

```swift
// ✅ 必须注释
/// 根据当前时间窗返回指定指标的 TrendDataPoint 数组，供图表渲染
func chartData(for metricType: MetricType) -> [TrendDataPoint] { ... }

// ✅ 可选注释（逻辑自解释时可省略）
private func startOfWeek(for date: Date) -> Date { ... }
```

### 1.3 中英夹杂，业务概念用中文

```
/// Hero 卡片 — 当前值 + 净增量 + 百分比
/// 活跃度分析服务协议（Premium）
/// 加载指定账号在所有时间窗下的全部指标数据
/// DI 容器 — 单一入口创建并持有所有 Repository / Service
```

---

## 2. 注释位置规范

### 2.1 文件头部（不修改）

```swift
//
//  FileName.swift
//  Follower
//
//  Sigma: 简短的一句话描述文件职责。
//
```

文件头部注释在创建文件时编写，后续迭代**不修改**。如需补充细节，在 struct/class 的 `///` 注释中添加。

### 2.2 Struct / Class / Enum / Protocol

```swift
/// 多时间窗通用柱状图组件 — 日/周/月/年各自独立 Chart 实现，共享外层卡片 UI
struct TrendChart: View { ... }

/// 趋势页 ViewModel — 管理多时间窗指标数据加载、缓存与窗口切换
@MainActor
final class TrendsViewModel: ObservableObject { ... }

/// 时间窗枚举：日 / 周 / 月 / 年
enum TimeWindow: String, Codable { ... }

/// Snapshot 仓库协议 — 定义快照数据的 CRUD 操作
protocol SnapshotRepositoryProtocol { ... }
```

### 2.3 存储属性 / @Published

```swift
/// 图表中展示的六个指标类型，顺序固定
static let visibleMetricTypes: [MetricType] = [...]

/// 日视图的 24 小时逐时数据（由最新 Snapshot 实时生成）
@Published var hourlyData: [MetricType: [TrendDataPoint]] = [:]

/// 主题环境
@Environment(\.theme) private var theme
```

对于自解释的属性（如 `private let calendar = Calendar.current`），不强制要求注释。

### 2.4 函数 / 方法

```swift
/// 页面首次加载 — 获取首个账号并拉取其全部时间窗趋势数据
func loadInitialAccount() async { ... }

/// 注入依赖：TrialManager / ExportService / AccountRepo / PremiumRepo
init(trialManager: TrialManagerProtocol, ...) { ... }

/// 数值格式化：>=10K 显示 .1fK，>=1K 显示无小数，<1 保留两位
private func formatValue(_ value: Double) -> String { ... }
```

### 2.5 Computed Property（View Body / Subviews）

```swift
/// 根布局：加载 / 空状态 / 错误 / 内容分支
var body: some View { ... }

/// 全屏渐变背景，色彩随主题切换
private var backgroundView: some View { ... }

/// Premium Insights 区域 — 解锁后展示全部 9 张分析卡片，锁定状态仅显示锁+升级入口
private var premiumSection: some View { ... }
```

### 2.6 MARK 分区

```swift
// MARK: - Day Chart (24h 柱状图)
// MARK: - Premium
// MARK: - Empty State
// ── Shared Y Domain ──
```

`// MARK:` 用于 Xcode 导航栏分组，`// ──` 用于代码内部视觉分隔。

---

## 3. 测试代码注释规范

### 3.1 测试类

```swift
/// Premium 全服务单元测试：Prediction, Scoring, Retention, Activity, Comparison, Geo, AI
final class PremiumServicesTests: XCTestCase { ... }
```

### 3.2 测试方法

格式：`/// <输入场景> → <预期行为>`

```swift
/// 正常 Snapshot 序列 → 应返回有效分数 0-100
func testScoreEngagement_NormalSnapshot_ReturnsScore() async { ... }

/// 空数据 → 返回空数组，不崩溃
func testPredictSMA_WithEmptyData_ReturnsEmpty() async { ... }

/// 无选中账户 → loadAllData 不崩溃并安全返回
func testLoadPremiumInsights_NoAccount_DoesNotCrash() async { ... }

/// 点击 Follower Prediction 卡片 → 导航到详情页 → 可返回
func testNavigateToPredictionDetailAndBack() { ... }
```

### 3.3 Mock / Helper

```swift
/// Mock Snapshot 仓库：可预设返回值
final class MockSnapshotRepository: SnapshotRepositoryProtocol { ... }

/// 创建测试用 Snapshot，仅填充关键字段
private func makeSnapshot(followers: Int = 100, ...) -> Snapshot { ... }

/// 构建一个配置好 Mock 依赖的 ViewModel
@MainActor
private func makeViewModel(...) -> DashboardViewModel { ... }
```

### 3.4 setUp / tearDown

```swift
/// 测试准备 — 配置 UI_TEST 参数并启动 App
override func setUp() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["UI_TEST"]
    app.launch()
}
```

---

## 4. DIContainer / Service 注释规范

```swift
/// DI 容器 — 单一入口创建并持有所有 Repository / Service / Premium 分析服务
@MainActor
final class DIContainer: ObservableObject {

    // MARK: - Repositories
    let accountRepository: AccountRepositoryProtocol

    // MARK: - Services
    let aggregationService: AggregationServiceProtocol

    // MARK: - Gamma Premium Services
    /// 互动质量评分服务
    let scoringService: ScoringServiceProtocol

    /// 构造 DI 容器，按依赖顺序创建 Repository → Service → Premium 分析服务
    init(databaseManager: DatabaseManager) { ... }
}
```

---

## 5. 禁止事项

1. **禁止无意义的注释**
   ```swift
   // ❌
   /// 设置 x 为 5
   let x = 5

   // ✅ 无注释 — 变量名已经说明一切
   let maxRetryCount = 5
   ```

2. **禁止过时的注释** — 改代码时必须同步更新注释。

3. **禁止用注释解释糟糕的命名** — 重命名变量/函数比写注释更好。

4. **禁止大段英文注释** — 团队以中文为主，注释保持中英夹杂风格。

5. **禁止注释掉的代码** — 删除旧代码，用 git 回溯历史。

---

## 6. 常用注释模板

### Struct / View
```swift
/// <组件名> — <一句话职责>
struct ComponentName: View {
    /// <属性说明>
    let someProperty: Type

    /// 根布局
    var body: some View { ... }

    // MARK: - Subviews

    /// <子视图说明>
    private var subviewName: some View { ... }
}
```

### ViewModel
```swift
/// <页面> ViewModel — <职责概述>
@MainActor
final class ViewModelName: ObservableObject {

    // ── Dependencies ──
    private let repo: SomeRepositoryProtocol

    // ── Published State ──
    /// <状态说明>
    @Published var someState: Type = ...

    // MARK: - Public

    /// <方法说明>
    func publicMethod() async { ... }

    // MARK: - Private

    /// <私有方法说明>
    private func privateHelper() { ... }
}
```

### Service
```swift
/// <服务名>协议（Premium / Core）
protocol ServiceNameProtocol: Sendable {
    /// <方法说明>
    func doSomething(input: Type) async -> Output
}

/// <服务名>实现：<算法简述>
final class ServiceName: ServiceNameProtocol {
    /// <实现细节>
    func doSomething(input: Type) async -> Output { ... }
}
```

### Model
```swift
/// <模型说明>。GRDB Fetchable + Persistable。
struct ModelName: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    /// <字段说明>
    var fieldName: Type
}
```

### Test
```swift
/// <测试范围> 测试套件
final class TestsName: XCTestCase {

    // MARK: - <Section>

    /// <场景> → <预期结果>
    func testMethod_Scenario_ExpectedBehavior() async { ... }
}
```

---

## 7. 检查清单

新增或修改代码时：

- [ ] 每个新增的 `public` / `internal` struct/class/enum/protocol 有 `///` 注释
- [ ] 每个新增的 `public` / `internal` 函数有 `///` 注释
- [ ] 每个 `@Published` 属性有 `///` 注释（除非自解释）
- [ ] 每个 `var body` 和主要子视图有 `///` 注释
- [ ] 测试方法使用 `/// <场景> → <预期>` 格式
- [ ] Mock 类使用 `/// Mock <原类名> — <用途>` 格式
- [ ] 没有注释掉的代码残留
- [ ] 注释与代码逻辑一致（修改代码时同步更新）

---

**文档完。**
