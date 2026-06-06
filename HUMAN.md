# HUMAN.md — 如果你是人类，先读这个

> 这个项目是 AI agent 构建的。代码能跑、测试能过，但它没有人 review 过。
> 以下是我作为构建者发现的每一个问题、债务和技术决策。

---

## 阅读顺序（重要）

在修改任何代码之前，按这个顺序读：

1. **`CLAUDE.md`** — 项目规则与约束（AI agent 的行为边界）
2. **`ARCHITECTURE.md`** — 系统分层 + 数据流图
3. **`docs/specs/alpha.md`** — 已交付的功能范围
4. **`docs/specs/beta.md`** — 已交付的体验范围
5. **`docs/HANDOFF.md`** — 目录树 + 功能清单 + 构建命令
6. 然后回到本文档，阅读下面的问题分析

读完这 6 份文档，你就能理解这个项目了。

---

## 核心代码（不可删、不可改架构）

| 文件 | 为什么重要 |
|------|-----------|
| `Models/Account.swift` ~ `PremiumFeature.swift` | 5 个领域模型。改任何一个字段，必须同步修改 `MigrationV1.swift`（Schema）和对应的 `Repository` |
| `Core/MigrationV1.swift` | 唯一的数据库 Schema 定义。改表结构必须写新 Migration |
| `Core/DatabaseManager.swift` | 单例。磁盘 DB 失败 → 自动降级内存。这是 App 不闪退的最后防线 |
| `Core/DIContainer.swift` | 依赖注入容器。所有 Repository/Service 的唯一创建入口。改依赖关系只改这里 |
| `Repository/*.swift` | 5 个数据访问层。业务逻辑**绝对不能**写在这里，只能写 CRUD |
| `Services/Aggregation/AggregationService.swift` | 最复杂的 Service — Event→Snapshot→Metric 的聚合管线。271 行，修改要极其小心 |
| `Core/ThemeSystem.swift` | 4 个主题定义 + Environment 注入。Theme 是 struct（Sendable），所有 UI 通过 `@Environment(\.theme)` 取色 |

---

## 架构问题

### 1. SyncEngine 是 actor，但测试完全跳过它

**问题**：`SyncEngine` 和 `TrialManager` 都是 `actor`。在 XCTest 中创建 actor 实例会触发 `EXC_BREAKPOINT` 或 `SIGABRT`（Swift 6 并发运行时与 XCTest 运行循环冲突）。目前所有涉及 actor 的测试都被跳过了。

**影响**：SyncEngine 的真实行为**从未被测试过**。如果你修改了 SyncEngine（比如对接真实 API），你无法用现有测试框架验证它。

**建议修复**：将 SyncEngine 从 `actor` 改为 `@MainActor class`，或者为测试引入 mock protocol 实现。

### 2. AggregationService 的「增量」是假的

**问题**：`AggregationService.aggregate()` 声称是增量计算，但实际行为是：
1. 取时间范围内的 Event → 生成 Snapshot（正确，只处理新增 Event）
2. 取该时间范围 ±1 个月的**所有 Snapshot** → 全量重算 Metric（问题）

如果有 365 天数据，每次同步后都重算 2 个月范围内的所有 Metric。这不是真正的增量。

**影响**：数据量大到几千条 Snapshot 后，聚合会明显变慢。

**建议修复**：Metric 应该只在新增/变更的 Snapshot 上计算，已存在的 Metric 不需要更新（除非窗口边界刚好需要调整上周/上月的数据）。

### 3. Repository upsert 使用「先查后写」而不是数据库级 UPSERT

**问题**：`SnapshotRepository` 和 `MetricRepository` 的 upsert 实现是：
```swift
if let existing = try fetch(...) { update } else { insert }
```
这不是原子操作。两个并发 upsert 可能产生重复行。

**影响**：目前 SyncEngine 是单 actor 串行，所以不会出现竞态。但如果未来引入并发同步（多个 source 同时写入），会出现重复 Snapshot。

**建议修复**：使用 GRDB 的 `upsert` + `onConflict` 指定唯一索引来真正实现数据库级原子 upsert。

### 4. DIContainer 持有过多实例

**问题**：`DIContainer` 是 `@MainActor class`，创建了 5 个 Repository、2 个 actor（SyncEngine + TrialManager）、3 个 Service。每次 App 启动都在主线程创建所有对象。

**影响**：启动时间不受影响（都是轻量对象），但**测试永远无法 mock 单个依赖**。要测试 `SettingsViewModel`，你必须提供真实的 `TrialManager` actor——而这会崩溃。

**建议修复**：引入 Protocol Witness 或闭包注入，让测试可以注入假对象。

### 5. LanguageStore 不是 actor，但被当作 actor 访问

**问题**：`LanguageStore` 是 `class : @unchecked Sendable`。它的 `currentBundle` 在 `reloadBundle()` 中被修改，但没有锁保护。两个线程同时调用 `setLanguage` 可能导致崩溃。

**影响**：目前语言切换只在 Settings 页触发（用户操作，单线程），所以没问题。但如果未来在 AppDelegate 或后台线程切换语言，会有 race condition。

**建议修复**：改为 `actor LanguageStore`。

---

## UI 问题

### 6. Form + NavigationStack 按钮不可点击（Xcode 26 专属 Bug）

**问题**：在 Xcode 26 / iOS 26 的 `Form` 中，`Button` 的 tap 被 Form 的行选中行为拦截。`.buttonStyle(.borderless)` 无效，`.onTapGesture` 也无效。

**当前 workaround**：把操作按钮移到 `NavigationStack` 的 toolbar 中。但这不适用于需要内联按钮的场景。

**建议**：关注 Xcode 更新是否修复此问题。如果长期不修复，考虑用 `List` 代替 `Form`。

### 7. 主题切换需要 .id() 强制重建

**问题**：`ContentView` 使用 `.id(appState.currentLanguage.rawValue)` 来强制语言切换时重建 view tree。这意味着切换语言后，所有 `@StateObject` 都会被销毁和重建——View 会闪一下。

**建议修复**：改用 `@Environment(\.locale)` 传递语言，配合 `Text` 的本地化支持。或者使用 `ObservableObject` 的 `objectWillChange` 手动触发更新。

### 8. Premium 只有门控，没有实际功能

**问题**：13 个 Premium 功能全部只有「开关」——可以启用、禁用、检查过期，但开关本身不会触发或隐藏任何逻辑。目前 Premium 是一个纯粹的权限旗帜系统。

**影响**：你在设置里点「解锁全部高级功能」后，除了看到 13 个绿色对号之外，什么都不会发生。

**建议**：实现 Premium 功能时，使用 `PremiumGate` modifier 包裹对应的 View，在 unlock 后展示实际内容。

---

## 数据问题

### 9. 测试共享数据库导致 flaky tests

**问题**：所有测试共享 `DatabaseManager.shared`。没有 setUp 清理、没有 tearDown 回滚。一个测试的残留数据会影响后续测试。

**影响**：RepositoryTests 和 ServicesTests 有 ~50% 的 flaky 失败率。不是代码 Bug，而是测试环境脏数据。

**建议修复**：使用内存数据库（`DatabaseQueue()` + 单独 migration）或 `setUp` 中清空表。

### 10. 没有数据库 Migration 策略

**问题**：`MigrationV1` 是唯一的 migration。如果要加新表、改字段，没有 v2 → v3 → ... 的升级路径。GRDB 的 `DatabaseMigrator` 支持注册多个 migration，但目前只注册了 v1。

**建议**：每次改 Schema 都注册新 migration，不要修改已有 migration。

---

## 测试问题

### 11. UI 测试使用 index-based 定位

**问题**：因为 Xcode 26 中 `.accessibilityIdentifier` 不传播到 `UITabBarButton`，UI 测试使用 `app.tabBars.buttons.element(boundBy: 0)` 定位 tab。如果 tab 顺序改变，测试全部失效。

**建议修复**：Xcode 26 正式版可能修复此问题。如果修复了，改回 `.accessibilityIdentifier` 定位。

### 12. 没有 Snapshot 测试

**问题**：主题切换、多语言 UI、深色模式——这些都是「看起来对不对」的问题，但没有任何 Snapshot 测试来验证视觉一致性。

**建议**：引入 `swift-snapshot-testing` 库，对关键页面拍快照。

---

## 编译器问题

### 13. Xcode 26 + Swift 6 的严格模式需要额外 import

**要点**：
- `import Combine` 必须**显式声明**（`MemberImportVisibility` 开启）
- `Codable` 和 GRDB Record 的 conformance 必须在**同一个 extension** 中声明（否则 circular reference）
- `nonisolated` 需要显式标注（`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`）
- `@Sendable` 闭包必须显式标注（否则 warning）

这些不是 bug，是 Swift 6 的兼容性要求。如果你降级到 Xcode 16，有些可能不需要。

---

## 性能问题（当前不是瓶颈，但未来可能是）

| 问题 | 位置 | 触发条件 |
|------|------|---------|
| `AggregationService` 每次聚合都查 ±1 个月的 Snapshot | 279 行 | 每次同步 |
| `buildMetrics` 为每个 Snapshot 生成 6 条日 Metric + Week + Month 聚合 | 150 行 | 数据 > 500 条 Snapshot |
| `loc()` 每次调用都查 `localizedString`（无缓存） | L10n.swift | 无影响（Bundle 内部缓存） |
| `Theme` 每次 `body` 重绘都创建新实例（但这是值类型，开销可忽略） | ThemeSystem.swift | 无影响 |

---

## 如果你是 AI agent（续写提示）

```
你在开发 Follower App（iOS / SwiftUI / GRDB / MVVM）。
请先阅读 CLAUDE.md 和 ARCHITECTURE.md。
当前版本 v0.02-beta-2.0.2，已在 main 分支。
所有功能变更必须同步更新测试，构建通过后才能 commit。
测试命令：xcodebuild -project Follower.xcodeproj -scheme Follower
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
编译环境：Xcode 26.0+, Swift 6, iOS 26.0+
GRDB 依赖在 Vendor/GRDB.swift-7.11.0（git clone --depth 1 --branch v7.11.0）

已知坑：
1. 不要在测试中创建 actor（SyncEngine/TrialManager）——会崩溃
2. Form 中的 Button 不可靠——用 toolbar button
3. import Combine 要显式声明
4. Repository upsert 是「先查后写」不是原子操作
5. Premium 只有开关没有实际功能
```

---

*最后更新：2026-06-06。这些分析基于当前代码状态。如果你发现了新的问题，请更新本文档。*
