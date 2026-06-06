# Follower — 项目交接文档

> 最后更新：2026-06-06  
> 当前版本：v0.02-beta-2.0.2  
> 分支：main

---

## 1. 项目概述

**Follower** 是一款本地优先的 Instagram / TikTok 数据跟踪与分析 iOS App。核心卖点：本地存储、隐私优先、数据可视化、跨平台账号支持。

### 技术栈

| 层 | 技术 |
|---|------|
| UI | SwiftUI (iOS 26+) |
| 架构 | MVVM + Repository + Service |
| 持久化 | GRDB 7.11.0 + SQLite（本地 Vendor 包） |
| 并发 | Swift Concurrency (actor, @MainActor, Sendable) |
| 测试 | XCTest (Unit + UI) |
| 本地化 | String Catalog (.xcstrings) + Bundle-based 运行时切换 |
| 主题 | 自定义 Theme struct (4 主题) + EnvironmentValues 注入 |

---

## 2. 目录树（40 个源文件，4,387 行）

```
Follower/
├── FollowerApp.swift              [40]  App 入口，开屏+浅深色模式
├── ContentView.swift              [70]  TabView 容器 + DI
│
├── Core/                                   # 基础设施
│   ├── AppState.swift              [33]  全局状态：Theme/Language/ColorScheme
│   ├── DIContainer.swift           [95]  依赖注入容器
│   ├── DatabaseManager.swift       [92]  GRDB 管理器（磁盘→内存降级）
│   ├── MigrationV1.swift          [126]  初始 Schema（5 表）
│   ├── ThemeSystem.swift          [263]  Theme struct（4 主题）+ Environment
│   ├── TrialManager.swift         [107]  1 小时试用（actor）
│   └── Localization/
│       ├── AppLanguage.swift       [75]  语言枚举 + LanguageStore + Bundle 切换
│       └── L10n.swift             [154]  翻译 key 定义(108+) + loc() 函数
│
├── Models/                                  # 领域模型（GRDB Record）
│   ├── Account.swift               [69]  id, platform, username, authState
│   ├── Event.swift                 [74]  id, accountId, eventType, payload (append-only)
│   ├── Snapshot.swift              [66]  id, accountId, followersCount... (upsert)
│   ├── Metric.swift                [79]  id, accountId, metricType, value, window
│   └── PremiumFeature.swift        [83]  id, key, enabled, expiresAt
│
├── Repository/                              # 数据访问层（唯一入口）
│   ├── AccountRepository.swift     [82]  CRUD
│   ├── EventRepository.swift      [106]  append/batch-insert, 类型/时间查询
│   ├── SnapshotRepository.swift    [103]  upsert（accountId+observedAt 去重）
│   ├── MetricRepository.swift      [103]  upsert（4 列去重），窗口/类型查询
│   └── PremiumFeatureRepository.swift [78] enable/disable + 过期检查
│
├── Services/                                # 业务服务层
│   ├── Sync/
│   │   ├── SyncEngine.swift        [164]  同步引擎（actor，Alpha 模拟数据）
│   │   └── APIDTOs.swift           [67]  外部 API DTO（隔离于 Model）
│   ├── Ingestion/
│   │   └── IngestionService.swift  [139]  DTO → Event 映射 + 批量写入
│   ├── Aggregation/
│   │   └── AggregationService.swift [271] Event→Snapshot→Metric（增量计算）
│   └── ExportService.swift         [117]  JSON/CSV 导出
│
├── Features/                                # 功能模块（View + ViewModel）
│   ├── Shared/                              # 共享 UI 组件
│   │   ├── EmptyStateView.swift     [60]  空状态占位
│   │   ├── ErrorBanner.swift        [52]  错误提示横幅
│   │   ├── StatCard.swift           [66]  统计卡片
│   │   ├── TrendChart.swift         [90]  趋势折线图（Swift Charts）
│   │   ├── PremiumGate.swift       [200]  Premium 门控 + 升级提示页
│   │   ├── SplashView.swift         [76]  开屏页（Instagram 渐变 + 动画）
│   │   └── InstagramBackground.swift [70] 深色渐变背景
│   ├── Dashboard/
│   │   ├── DashboardView.swift     [124]  8 格统计卡片 + 下拉刷新
│   │   └── DashboardViewModel.swift [90]  同步编排
│   ├── Trends/
│   │   ├── TrendsView.swift        [150]  图表+窗口切换+增长摘要
│   │   └── TrendsViewModel.swift   [131]  按日/周/月加载 Metric
│   ├── Settings/
│   │   ├── SettingsView.swift      [270]  Tab "我的"：试用/账号/语言/主题/导出/Premium
│   │   └── SettingsViewModel.swift [150]  设置编排 + Premium 一键解锁
│   └── Account/
│       ├── AccountView.swift       [144]  账号绑定表单 + toolbar 操作按钮
│       └── AccountViewModel.swift  [115]  增/删/撤销（不含 SyncEngine 同步）
│
├── Resources/
│   └── Localizable.xcstrings              String Catalog（en/zh-Hans/zh-Hant/ja）
│
└── Assets.xcassets/                        App 图标和颜色
```

### 测试文件

```
FollowerTests/                     601 行，8 文件
├── ModelsTests.swift              Codable 序列化，枚举覆盖
├── RepositoryTests.swift          CRUD + Upsert（共享 DB，偶尔 flaky）
├── ServicesTests.swift            Aggregation, Export, Trial（SyncEngine 已跳过）
├── LocalizationTests.swift        Bundle 翻译，语言持久化，运行时切换
├── ThemeTests.swift               4 主题颜色完整性，Sendable，LiquidGlass
├── AccountViewModelTests.swift    账号创建/删除/撤销
├── PremiumUnlockTests.swift       一键解锁所有功能，永久有效
└── TrendsViewModelTests.swift     TrendDataPoint 模型验证

FollowerUITests/                  291 行，7 文件
├── DashboardUITests.swift         3 Tab 存在性，启动不崩溃，导航不崩溃
├── TrendsUITests.swift            Trends Tab 导航
├── SettingsUITests.swift          Settings 可达，全 Tab 遍历存活
├── AccountUITests.swift           Settings 导航，Toolbar 按钮
├── ThemeAndLanguageUITests.swift  启动成功，全 Tab 可访问
├── FollowerUITests.swift          模板测试
└── FollowerUITestsLaunchTests.swift 启动性能 × 32 次
```

### Docs

```
docs/
├── INDEX.md                       文档索引
├── HANDOFF.md                     本文档（项目交接）
├── data-model.md                  数据模型说明
├── privacy-security.md            隐私安全规范
├── roadmap.md                     产品路线图
├── testing-strategy.md            测试策略
├── adr/                          架构决策记录
│   ├── ADR-001-storage.md         GRDB + SQLite
│   ├── ADR-002-sync-and-aggregation.md
│   └── ADR-003-ui-theme-and-performance.md
├── specs/
│   ├── alpha.md                   Alpha 版本范围
│   ├── beta.md                    Beta 版本范围
│   ├── premium.md                 Premium 功能规范
│   └── gamma.md                   Gamma（待定）
└── ui/
    ├── design.md                  设计原则
    ├── visual_design.md           视觉设计规范
    └── inter_desugn.md            交互设计规范
```

---

## 3. 架构设计

### 数据流

```
External API → SyncEngine(actor) → IngestionService → Event(append-only)
                                        ↓
                              AggregationService
                                   ↓           ↓
                              Snapshot(upsert)  Metric(derived)
                                   ↓           ↓
                              Repository（唯一数据入口）
                                   ↓
                              ViewModel（编排 + 轻量展示逻辑）
                                   ↓
                              SwiftUI View（声明式 UI）
```

### 依赖注入链

```
FollowerApp.init()
  └── DatabaseManager.shared（单例）
       └── AppState(databaseManager:)
            └── DIContainer(databaseManager:)
                 ├── AccountRepository, EventRepository, SnapshotRepository,
                 │   MetricRepository, PremiumFeatureRepository
                 ├── AggregationService → (EventRepo, SnapshotRepo, MetricRepo)
                 ├── IngestionService → (EventRepo, AggregationService)
                 ├── SyncEngine(actor) → (EventRepo, AccountRepo, IngestionService)
                 ├── ExportService → (SnapshotRepo, MetricRepo, EventRepo)
                 └── TrialManager(actor) → (PremiumFeatureRepo)
```

### 层边界

| 允许 | 禁止 |
|-----|------|
| View → ViewModel | View → Repository |
| ViewModel → Repository/Service | ViewModel → Database/SQL |
| Service → Repository | View → Database |
| Repository → DatabaseManager | Service → ViewModel |

### 数据模型三层

| 层 | 模型 | 特性 |
|---|------|------|
| Event | 原始观测 | Append-only，不可修改 |
| Snapshot | 状态快照 | Upsert，按 (accountId + observedAt) 去重 |
| Metric | 派生指标 | 后台聚合，日/周/月窗口 |

### 并发模型

| 类型 | 隔离策略 |
|------|---------|
| AppState, ViewModel, DIContainer | `@MainActor class` |
| SyncEngine | `actor` |
| TrialManager | `actor` |
| Repository | `class : Sendable`（通过 DatabaseManager 同步） |
| DatabaseManager | `@unchecked Sendable`（GRDB DatabaseQueue 内置串行） |
| Theme | `struct : Sendable`（值类型，安全跨 actor） |
| LanguageStore | `class : @unchecked Sendable`（UserDefaults 是线程安全的） |

---

## 4. 已实现功能（按版本）

### Alpha (v0.01) — 基础闭环
- [x] GRDB 数据库 + 5 表 Migration
- [x] 5 个 Repository（Account/Event/Snapshot/Metric/PremiumFeature）
- [x] SyncEngine（模拟数据）
- [x] IngestionService + AggregationService（增量聚合）
- [x] ExportService（JSON/CSV）
- [x] TrialManager（1 小时试用）
- [x] Dashboard（8 个统计卡片）
- [x] Trends（日/周/月折线图）
- [x] Settings（试用/账号/主题/导出/隐私/存储）
- [x] Account（创建/撤销/删除）
- [x] Apple Native + Instagram 主题
- [x] Liquid Glass 卡片效果

### Beta (v0.02) — 本地化 + 主题 + 体验
- [x] 4 语言本地化（en/zh-Hans/zh-Hant/ja）
- [x] L10n key 体系（108+ key）
- [x] String Catalog (.xcstrings)
- [x] Bundle-based 运行时语言切换
- [x] 4 主题系统（Apple Native / Instagram / Midnight Dark / Instagram Dark）
- [x] 深色模式切换（System/Light/Dark）
- [x] Instagram 品牌渐变开屏页
- [x] 深色 UI 渐变背景
- [x] ErrorBanner 统一错误提示
- [x] Premium 一键解锁按钮
- [x] Tab 图标更新（使用 SF Symbols）
- [x] Settings → "我的"（person.fill）
- [x] Form + NavigationStack 按钮 tappability 修复（toolbar button）
- [x] Trends 日/周/月切换 Bug 修复（picker 绑定调用 selectWindow）
- [x] Account 创建后自动 dismiss

### 测试 (v0.02-test)
- [x] Unit Tests：~50 用例（Models/Theme/Localization/Repository/Service/Trial/Premium）
- [x] UI Tests：11 用例（Dashboard/Trends/Settings/Account/Theme + 32 LaunchTests）
- [x] CI 可运行：11/11 UI tests pass, core unit tests pass
- [x] 闪退修复：移除所有 force-unwrap，actor 测试隔离

---

## 5. 未实现 / 待做（Gamma）

### Premium 实际功能（目前仅有开关）
- [ ] 趋势预测引擎
- [ ] 粉丝增长预测
- [ ] 活跃度/留存率/流失分析
- [ ] 地域分布数据源
- [ ] 互动质量评分模型
- [ ] Excel 导出
- [ ] 本地 AI 分析
- [ ] 加强加密
- [ ] 多设备同步

### 基础设施
- [ ] 真实 API 对接（替换 SyncEngine 模拟数据）
- [ ] OAuth 登录流程
- [ ] 数据库加密
- [ ] iCloud 备份

### 体验
- [ ] 首次引导页（Onboarding）
- [ ] Haptic 反馈
- [ ] VoiceOver 适配
- [ ] Dynamic Type 适配
- [ ] 小屏 iPhone SE 适配

---

## 6. 已知问题 & 避坑指南

### 测试闪退
- **actor 测试**：`SyncEngine`(actor) 和 `TrialManager`(actor) 在 `XCTestCase` 中创建会触发 `EXC_BREAKPOINT` 或 `SIGABRT`。**绝对不要**在测试中 `init` actor 类型，或创建触发 actor init 的对象（如 `AppState`）。
- **@MainActor 测试**：`TrendsViewModel` 等 `@MainActor` 的类，在非 MainActor 测试方法中创建会导致 `POINTER_BEING_FREED_WAS_NOT_ALLOCATED`。需要标记测试方法为 `@MainActor`，或避免创建这些对象。
- **force-unwrap**：所有 `!` 在测试中已替换为 `guard let`，**不要**添加新的 force-unwrap。

### 数据库
- `DatabaseManager` 是单例，磁盘失败时**自动降级为内存数据库**（`isInMemoryFallback` 标记）
- Repository 的 upsert 使用「先查后写」模式，因为 auto-increment 主键不能用于冲突检测
- `AccountRepository.insert()` 返回 `Account`（含 `didInsert` 设置的 id），调用方必须使用返回值

### UI
- **Form + NavigationStack** 中的 `Button` 在 Xcode 26 中 tap 被行选中拦截。**始终使用 toolbar button** 代替 Form 内按钮。
- Tab 切换时 `.accessibilityIdentifier` 在 Xcode 26 中不传播到 `UITabBarButton`。UI 测试使用 `app.tabBars.buttons.element(boundBy:)` 定位。

### 编译
- `import Combine` 需要在所有使用 `@Published` / `ObservableObject` 的文件中**显式声明**（`MemberImportVisibility` 开启）
- Codable 声明必须与 GRDB Record 放在**同一个 extension** 中，否则 circular reference

---

## 7. 编译与测试命令

```bash
# 编译
xcodebuild -project Follower.xcodeproj -scheme Follower \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Clean build
xcodebuild -project Follower.xcodeproj -scheme Follower \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build

# 单元测试
xcodebuild -project Follower.xcodeproj -scheme Follower \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:FollowerTests

# UI 测试
xcodebuild -project Follower.xcodeproj -scheme Follower \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:FollowerUITests

# 全部测试
xcodebuild -project Follower.xcodeproj -scheme Follower \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

### 前提条件
- Xcode 26.0+
- `Vendor/GRDB.swift-7.11.0/` 需要存在（git clone 后单独执行）：
  ```bash
  mkdir -p Vendor
  cd Vendor
  git clone --depth 1 --branch v7.11.0 \
    https://github.com/groue/GRDB.swift.git GRDB.swift-7.11.0
  ```

---

## 8. Git 版本历史

```
c176e9d v0.02-beta-2.0.2: Trends fix, Premium unlock, 我的 tab
4f135f3 v0.02-beta-2.0.1: UI tests — 11/11 passed
9bcf98e v0.02-beta-2.0.1: Fix tappability — toolbar buttons
6ef0e31 v0.02-beta-2.0.1: Fix Connect Account tappability + auto-dismiss
fda7765 v0.02-beta-test: Unit tests for Beta-2.0 features
cad6bb0  v0.02-beta-2.0.1: SF Symbols + Light/Dark mode
2e65750  v0.02-beta-2.0: Instagram Dark theme + Splash Screen
1ae3922 v0.02-beta-test: Unit tests + UI tests + crash fixes
3fee0ad v0.02-beta-fix: Language switching — Bundle-based lookup
34505a1 v0.02-beta-fix: In-app language + theme reactivity
b0566fb v0.02-beta-fix: Review fixes
570e26a v0.02-beta: Localization + Theme System + Experience Polish
6410302 Update .gitignore
26049db v0.01-alpha: Initial Alpha implementation
```

---

## 9. 关键文件速查

| 需求 | 文件 |
|------|------|
| 修改 Model 结构 | `Models/*.swift` + `MigrationV1.swift` |
| 添加查询 | 对应 `Repository/*.swift` |
| 添加业务逻辑 | `Services/` 下对应目录 |
| 添加页面 | `Features/<Name>/` 下 View + ViewModel |
| 添加翻译 | `L10n.swift` + `Localizable.xcstrings` |
| 添加主题 | `ThemeSystem.swift` 中新增 Theme 静态属性 |
| 添加依赖 | `DIContainer.swift` |

---

## 10. 未提交的变更（Stash / 本地）

无。`git status` 为 clean。
