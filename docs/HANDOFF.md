# Follower — 项目交接文档 v3

> 最后更新：2026-06-08  
> 当前版本：v0.04-lambda-2.0  
> 活跃分支：`main`(alpha/beta), `gamma`, `lambda`  
> 统计：60 源文件 · 5,864 行代码 · 20 测试文件 · 1,575 行测试 · 39 commits

---

## 0. 适合人类接手吗？

**适合，但需要读完本文档。** 这个项目不是 AI 生成的不可维护代码。它有清晰的架构分层、一致的命名约定、可运行的测试套件。一个熟悉 Swift/iOS 的开发者花 2-3 小时读完文档和核心代码后可以开始贡献。

最大的优势是**架构纪律**——Model/Repository/Service/ViewModel/View 的边界从未被破坏。最大的挑战是几个已知的技术债务点，下面都列出来了。

---

## 1. 当前状态

### 1.1 各分支功能

| 分支 | 版本 | 核心交付 |
|------|------|---------|
| `main` | v0.02-beta-2.0.2 | 完整的 iOS 分析 App：Dashboard/趋势/设置/账号 + 4 语言本地化 + 4 主题 |
| `gamma` | v0.03 | Premium 分析服务（Scoring/Prediction/Comparison 等 7 个）+ TikTok 移除 |
| `lambda` | v0.04 | Dashboard UX 重构（Hero 粉丝 + 次要指标 + 帖子列表 + Premium 交互详情页） |

### 1.2 数据状态

**全部是 Mock 数据**——没有对接任何真实 API。SyncEngine 生成随机数字。帖子列表、取关名单、地域分布都是 MockPostGenerator 和 MockFollowerListGenerator 生成的假数据。

---

## 2. 最大优势

### 2.1 架构一致性强

从第一个文件到最后一个文件，MVVM + Repository + Service 的分层从未被打破。ViewModel 里没有 SQL，View 里没有数据库调用，Repository 里没有 UI 代码。这不是一个"部分 MVVM"的项目——每一层都在它应该在的位置。

### 2.2 GRDB 选择正确

Event/Snapshot/Metric 三层数据模型是正确的设计。Event 是 append-only 的原始记录，Snapshot 是可 upsert 的 UI 快照，Metric 是后台计算的派生指标。这个设计让你可以删除 Metric 重新计算而不丢失原始数据——这在数据分析 App 中至关重要。

### 2.3 测试框架完整

- 75 个单元测试（61 必须通过，14 共享 DB flaky）
- 12 个 UI 测试
- GitHub Actions CI（macOS 26 runner）在每次 PR 时运行
- 测试按"必须通过"和"已知 flaky"分组

### 2.4 本地化系统实用

`loc()` 函数通过 Bundle-based 查找实现运行时语言切换，无需重启 App。108+ key 覆盖 4 种语言。String Catalog (.xcstrings) 作为数据源。

### 2.5 主题系统干净

`Theme` 是 Sendable struct（非 protocol），安全跨 actor 边界。4 个主题用静态属性定义，Environment 注入。

---

## 3. 已知缺陷和何时会出问题

### 3.1 SyncEngine 是 actor——测试永远覆盖不了

**当前影响**：SyncEngine 的行为从未被测试。所有涉及 SyncEngine 的单元测试都会在 XCTest 中触发 `EXC_BREAKPOINT` 或 `SIGABRT`。

**临界点**：对接真实 Instagram API 时。届时你需要修改 SyncEngine 的核心逻辑（HTTP 请求、token 刷新、重试策略），但无法为这些改动写测试。

**修复方向**：将 SyncEngine 从 `actor` 改为使用串行 DispatchQueue 的 class，或引入 mock protocol。

### 3.2 AggregationService 的"增量"是假的

**当前影响**：`aggregate()` 声称增量计算，但每次同步后都重新读取 ±1 个月的所有 Snapshot 来 rebuild Metric。数据 30 天时无感，365 天后会明显变慢。

**临界点**：~500 条 Snapshot（约 1.5 年数据）。或者首次对接真实 API 时——如果用户有 2 年历史数据，第一次全量同步会触发这个性能瓶颈。

**修复方向**：只对新增/变更的 Snapshot 计算对应的 Metric，已存在的 Metric 不需更新（除非跨月/周的边界数据需要调整）。

### 3.3 DIContainer 过紧耦合

**当前影响**：无法单独 mock 某个依赖。所有 ViewModel 必须通过 DIContainer 获取真实的 Repository/Service 实例。SettingsViewModel 依赖 TrialManager（actor），导致 SettingsViewModel 也无法在单元测试中创建。

**临界点**：当你需要为 ViewModel 写单元测试时（而不是通过 UI 测试间接验证）。

**修复方向**：引入 Protocol Witness 或闭包注入。优先解决 TrialManager 和 SyncEngine 的 mock 问题——它们是 actor，是测试的头号障碍。

### 3.4 Repository upsert 不是原子操作

**当前影响**：`SnapshotRepository.upsert()` 和 `MetricRepository.upsert()` 使用"先查后写"模式（`if exists { update } else { insert }`），不是数据库级 UPSERT。两个并发 upsert 可能产生重复行。

**临界点**：引入并发同步时（多个数据源同时写入）。目前单 SyncEngine 串行调用，不会触发。

**修复方向**：使用 GRDB 的 `upsert` + `onConflict` 指定唯一索引。

### 3.5 共享 DatabaseManager 单例导致测试 flaky

**当前影响**：RepositoryTests 和 ServicesTests 的 14 个测试共享同一个 SQLite 数据库。前一个测试的残留数据影响后续测试。约 8% 的测试有不稳定的失败率。

**临界点**：已经是一个问题，但 CI 通过 `|| true` 绕过了。

**修复方向**：为 DatabaseManager 添加 `static func inMemory() -> DatabaseManager` 工厂方法，测试用内存数据库。

### 3.6 Form + Button 在 Xcode 26 中不可点击

**当前影响**：所有 Form 中的 Button 都被 Form 的行选中行为拦截。`.buttonStyle(.borderless)` 无效，`onTapGesture` 也无效。我们用了 toolbar button 作为 workaround。

**临界点**：已经是一个问题。如果你需要在 Form 行内放交互式按钮（比如每行一个开关），目前的 workaround 不够。

**修复方向**：关注 Xcode 更新是否修复。或使用 `List` 替代 `Form`。

### 3.7 Premium 功能是 Mock

**当前影响**：解锁 Premium 后显示的"谁取关了你""最佳发帖时间"等详情页都是随机生成的假数据。13 个 PremiumFeature key 只在数据库中作为权限旗帜存在。

**临界点**：当你需要 Show 给真实用户而不是 Demo 时。

**修复方向**：对接 Instagram Graph API 获取真实数据。优先实现 CSV 导出增强和 Excel 导出——这些不需要外部 API。

---

## 4. 代码膨胀临界点预测

| 规模 | 可能出现的问题 | 建议 |
|------|--------------|------|
| **~80 源文件** (当前 60) | Dashboard 目录文件过多，Feature 内组件混杂 | 创建 `Dashboard/Components/` 子目录 |
| **~15 个 ViewModel** (当前 4) | ContentView 的 ViewModel 创建代码过长 | 引入 ViewModelFactory 或 Coordinator |
| **~20 个 Repository 方法** (当前 5-7 个/Repo) | 查询参数组合爆炸，方法签名变长 | 引入 QueryBuilder 或 Specification 模式 |
| **~2000 行/Service** (当前最大 271) | AggregationService 变 God Object | 拆分为 SnapshotBuilder + MetricBuilder + WeeklyAggregator 等 |
| **对接真实 API** | SyncEngine 变成最复杂的 Service，actor 测试问题变致命 | 将 SyncEngine 改为 protocol + mock 实现 |
| **3+ 开发者** | DIContainer 成为 merge conflict 热点，每个人都要碰同一个文件 | 引入模块化 DI（每个 Feature 自己注册依赖） |

TL;DR：**当前架构在 80-100 源文件、15,000 行以内不会出结构性问题。** 真正需要重构的信号是对接真实 API 和多开发者协作。

---

## 5. 阅读指南

### 5.1 必须读的 6 个文件（按顺序）

1. `CLAUDE.md` — 项目规则和行为约束
2. `ARCHITECTURE.md` — 系统分层和数据流
3. 本文档（HANDOFF.md）— 你在读的这个
4. `Core/DIContainer.swift` — 依赖注入入口，理解整个对象图
5. `Core/DatabaseManager.swift` — 数据库单例，磁盘→内存降级逻辑
6. `Models/` 下 5 个文件 — 理解 Event/Snapshot/Metric 三层模型

### 5.2 修改指南

| 你想做什么 | 改哪个文件 |
|-----------|----------|
| 加新页面 | `Features/<Name>/` 下新建 View + ViewModel |
| 加新数据表 | `Models/` + `MigrationV1.swift` → 注册 MigrationV2 |
| 加新 Service | `Services/` 下新建 + 在 `DIContainer.swift` 注册 |
| 加新查询 | 对应的 `Repository/` 文件 |
| 加翻译 | `Core/Localization/L10n.swift` + `Resources/Localizable.xcstrings` |
| 加主题 | `Core/ThemeSystem.swift` 新增 static let |

### 5.3 绝对不要做的事

1. 在 ViewModel 中写 SQL 或直接访问 DatabaseManager
2. 在 View 中直接调用 Repository
3. 在测试中创建 SyncEngine 或 TrialManager（actor 崩溃）
4. 修改已注册的 Migration（只新增 MigrationV2, V3...）
5. 把 Mock 数据当作真实数据源传输到生产环境

---

## 6. 编译和测试命令

```bash
# 全量编译
xcodebuild -project Follower.xcodeproj -scheme Follower \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/FollowerDD build

# 运行核心单元测试
xcodebuild -project Follower.xcodeproj -scheme Follower \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/FollowerDD \
  test -only-testing:FollowerTests/LambdaTests \
       -only-testing:FollowerTests/PremiumSyncTests

# 注意：不要本地跑 UI 测试（GIT.md 规则）。UI 测试通过 GitHub Actions CI 运行。
```

### 前提条件

- Xcode 26.0+
- `Vendor/GRDB.swift-7.11.0` 需要存在：
  ```bash
  mkdir -p Vendor
  cd Vendor && git clone --depth 1 --branch v7.11.0 \
    https://github.com/groue/GRDB.swift.git GRDB.swift-7.11.0
  ```
- 如果 DerivedData 在外部磁盘，使用 `-derivedDataPath /tmp/FollowerDD`
