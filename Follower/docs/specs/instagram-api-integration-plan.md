# Instagram API 接入计划

> **日期**：2026-07-25
> **状态**：待实施
> **目标**：用真实 Instagram Graph API 替换所有假数据，分两步实施

---

## 前置：已删除的假数据（git diff HEAD）

以下代码已在当前分支删除，是本次接入需要替换的目标：

| 文件 | 删除内容 | 行数 |
|------|---------|------|
| `SyncEngine.swift` | `generateMockProfile()` + `generateMockTrend()`（365 天随机粉丝数据） | 76 |
| `MockPostGenerator.swift` | 随机帖子生成器（标题、点赞、评论、曝光全随机） | 63 |
| `TrendsViewModel.swift` | `generateHourlyData()` + `mockHourly()` + `selectWindow()` | 57 |
| `MockFollowerListGenerator.swift` | 随机取关列表生成器 | 42 |
| `GrowthFeatures.swift` | `extension GrowthFeatures { static let mock }`（硬编码 1800/6200 followers） | 38 |
| `GeoDistributionService.swift` | `final class GeoDistributionService`（硬编码 9 个国家占比） | 20 |
| `GrowthScores.swift` | `extension GrowthScores { static func mock() }`（硬编码评分） | 13 |
| `EngagementDetailView.swift` | `MockEngagementGenerator.daily()`（7 天 `Double.random`） | 7 |
| **合计** | | **316 行** |

---

## 当前编译阻断点

删除了以上代码后，以下 12 处引用导致编译失败：

### Mock 类型引用（类型不存在）

```
PostDetailView.swift:11       →  let post: MockPost
PostListView.swift:11         →  let posts: [MockPost]
DashboardViewModel.swift:84   →  var recentPosts: [MockPost]
DashboardViewModel.swift:115  →  var unfollowList: [MockFollower]
DashboardViewModel.swift:228  →  MockPostGenerator().generate(count: 5)
DashboardViewModel.swift:306  →  MockFollowerListGenerator().generateUnfollows(count: 4)
DashboardView.swift:299       →  let posts: [MockPost]
DashboardView.swift:313       →  MockPostGenerator().generate(count: 20)
EngagementDetailView.swift:64 →  MockEngagementGenerator.daily()
UnfollowListView.swift:14     →  let followers: [MockFollower]
PostRowView.swift:12          →  let post: MockPost
FollowerDetailView.swift:70   →  MockFollowerListGenerator().generateUnfollows(count: 6)
```

### 残留随机数生成（运行时假数据）

```
PredictionDetailView.swift:19  →  Int.random 90 天假历史曲线
DashboardViewModel.swift:307   →  .randomElement() 随机最佳发帖时间
DashboardViewModel.swift:308   →  .randomElement() 随机内容策略建议
DashboardViewModel.swift:309   →  Int.random 预测粉丝数（+50~500 噪声）
BestTimeView.swift:103         →  Double.random 7×24 热力图回退矩阵
TrendChart.swift:397,408,420,430 →  Double.random（#Preview 块）
TrendDetailView.swift:50       →  Double.random（#Preview 块）
```

---

## 第一步：Token 认证 + API 客户端 + 数据管线

### 目标

用真实的 `IGAA...` access token 替换假登录流程，打通 Instagram API → Event → Metric → 图表的完整数据管线。

### 1.1 新建文件

```
Follower/Services/API/
├── InstagramAPIClient.swift   # URLSession + async/await HTTP 客户端
└── TokenProvider.swift        # Keychain 存取 access token（按 accountId）
```

**InstagramAPIClient** 封装三个端点，一次 `sync()` 共 3 次 API 调用：

| 方法 | 端点 | 用途 |
|------|------|------|
| `fetchProfile(token)` | `GET /me?fields=id,username,name,followers_count,follows_count,media_count` | 用户资料 → `APIProfileResponse` |
| `fetchInsights(token)` | `GET /me/insights?metric=follower_count,reach,impressions&period=day` | 三个时间序列按日期合并 → `APITrendResponse` |
| `fetchMedia(token, limit:25)` | `GET /me/media?fields=id,caption,media_type,timestamp,like_count,comments_count` | 最近帖子 → `[MediaPost]` |

API 设计要点：
- 基础 URL：`https://graph.instagram.com`（Instagram Login 路径）
- 统一错误映射：HTTP status → `APIError`（network/unauthorized/rateLimited/serverError/decodingFailed）
- 速率限制告警：200 次/小时/用户，接近阈值时 log 告警
- `IGInsightValue` 模型：匹配 Instagram Insights API 的 `{name, period, values: [{end_time, value}]}` 结构

**TokenProvider** Keychain 操作：

| 方法 | Keychain API | 用途 |
|------|-------------|------|
| `storeToken(accountId:, token:)` | `SecItemAdd` | 首次存储 |
| `getToken(accountId:) -> String` | `SecItemCopyMatching` | 获取（sync 时用） |
| `deleteToken(accountId:)` | `SecItemDelete` | 撤销账号时清理 |

### 1.2 修改文件

**AccountViewModel** — Token 替代手填表单

删除 `addAccount()`（手填 username + displayName 的假登录）。

新增 `connectWithToken(_ token: String) async`：
1. 调用 `apiClient.fetchProfile(token)` → `/me` 验证 token 有效性
2. 成功 → 用 API 返回的真实 `username` 创建 `Account`
3. Token 存入 `TokenProvider`（Keychain，按 accountId）
4. 立即触发 `syncEngine.sync(accountId:)`（首次全量同步）
5. 刷新账号列表

**AccountView** — Token 输入 UI

删 username/displayName 的 TextField，改为：
- 一个 `SecureField`（粘贴 `IGAA...` token）
- 一个 "Connect Instagram" 按钮（调用 `viewModel.connectWithToken(_:)`）
- 已有账号列表显示真实 API 返回的 username

**SyncEngine** — 真实 API 替换 Mock

`sync()` 方法改为：

```swift
func sync(accountId: Int64) async throws -> SyncResult {
    let token = try await tokenProvider.getToken(accountId: accountId)

    // 并行 3 次 API 调用
    async let user = apiClient.fetchProfile(token: token)
    async let insights = apiClient.fetchInsights(token: token)
    async let media = apiClient.fetchMedia(token: token)

    let profileDTO = user.toDTO()
    let trendDTO = mergeInsightsToTrend(insights)

    // 走现有管线（IngestionService → AggregationService 不改）
    return try await ingestionService.ingest(accountId:, profile: profileDTO, trend: trendDTO)
}
```

`mergeInsightsToTrend` 合并 3 个 insights 时间序列：
- `follower_count` → `APITrendDataPoint.followersCount`
- `impressions` → `APITrendDataPoint.totalViews`
- 按 `end_time` 日期对齐 → 90 天 `APITrendResponse`

**DIContainer** — 注入新依赖

新增：
```swift
let apiClient = InstagramAPIClient()
let tokenProvider = TokenProvider()
// SyncEngine init 新增参数 apiClient + tokenProvider
```

**SettingsView** — AccountViewModel 初始化传新参数

### 1.3 数据管线验证

第一步完成后，以下链路应跑通：

```
用户粘贴 IGAA...token
  → apiClient.fetchProfile(token)  ← 验证 + 获取真实 username
  → Account(username: "zaneliao", ...) ← 持久化
  → TokenProvider.storeToken(accountId: 1, token: "IGAA...")  ← Keychain
  → SyncEngine.sync(accountId: 1)
    → apiClient.fetchProfile(token)      → APIProfileResponse（真实粉丝数）
    → apiClient.fetchInsights(token)     → APITrendResponse（真实粉丝趋势）
    → apiClient.fetchMedia(token)        → [MediaPost]（真实帖子）
    → IngestionService.ingest(profile, trend)
      → AggregationService.aggregate()
        → Event → Snapshot → Metric（6 种 × 4 窗口）
          → Dashboard / Trends / Premium 图表
```

---

## 第二步：清除所有 .random() 假数据并替换 Mock 类型

### 目标

消除项目中剩余的 10 处 `.random()` 调用，新建 `MediaPost` + `UnfollowEntry` 替代已删除的 `MockPost` + `MockFollower`，修复所有编译错误。

### 2.1 新建模型文件

**`Models/MediaPost.swift`** — 替代 `MockPost`

```swift
struct MediaPost: Identifiable, Sendable {
    let id: Int64
    let igMediaID: String
    let type: MediaPostType       // .image / .video / .carousel
    let date: Date
    let likes: Int
    let comments: Int
    let caption: String
    let mediaURL: String?
    let permalink: String?
    // 格式化属性: formattedLikes, formattedComments, typeIconName, colorHex
}

enum MediaPostType: String, Sendable { case image, video, carousel }
```

数据来源：`SyncEngine.sync()` 中 `apiClient.fetchMedia()` 返回的 `IGMedia` 数组 → `compactMap { $0.toMediaPost() }`。

**`Models/UnfollowEntry.swift`** — 替代 `MockFollower`

```swift
struct UnfollowEntry: Identifiable, Sendable {
    let id: String
    let username: String
    let displayName: String
    let date: Date
    let isUnfollow: Bool
}
```

数据来源：`DashboardViewModel.computeUnfollowList()` 基于两次 Snapshot 的 `followersCount` 差值推算（Instagram API 不支持取关列表）。

### 2.2 清除 .random() 调用

| 文件 | 当前假数据 | 替换方案 |
|------|-----------|---------|
| `PredictionDetailView:19` | `Int.random` 90 天假曲线 | 新增 `historical: [Double]` 参数，由 `viewModel.sparklineData` 传入 |
| `DashboardViewModel:307` | `["Wed 7PM", ...].randomElement()` | 基于真实 `MediaPost` 数组，按 weekay 分组统计平均 likes 最高的那天 |
| `DashboardViewModel:308` | `["Carousel posts...", ...].randomElement()` | 基于真实 `MediaPost` 的 `MediaPostType` 分布生成建议 |
| `DashboardViewModel:309` | `Int.random(in: 50...500)` | 使用 `predictionResult.predictedValue`（`PredictionService.predictLinear()` 的线性回归结果） |
| `BestTimeView:103` | `generateHeatmap()` `Double.random` 7×24 | 无真实数据时返回全零矩阵，不随机 |
| `TrendChart.swift` Previews | `Double.random` 4 处 | 删除 `#Preview` 块或替换为静态示例数据 |
| `TrendDetailView.swift` Preview | `Double.random` 1 处 | 同上 |

### 2.3 修复 Mock 类型引用 → 新类型

| 文件 | 旧类型 | 新类型 |
|------|--------|--------|
| `PostRowView.swift` | `MockPost` | `MediaPost` |
| `PostDetailView.swift` | `MockPost` | `MediaPost` |
| `PostListView.swift` | `[MockPost]` | `[MediaPost]` |
| `DashboardView.swift:299` | `[MockPost]` | `[MediaPost]` |
| `DashboardView.swift:313` | `MockPostGenerator().generate()` | `posts`（已有数据） |
| `DashboardViewModel.swift:84` | `[MockPost]` | `[MediaPost]` |
| `DashboardViewModel.swift:115` | `[MockFollower]` | `[UnfollowEntry]` |
| `DashboardViewModel.swift:228` | `MockPostGenerator().generate()` | `syncEngine.fetchRecentMedia()` |
| `DashboardViewModel.swift:306` | `MockFollowerListGenerator().generateUnfollows()` | `computeUnfollowList()` |
| `EngagementDetailView.swift:64` | `MockEngagementGenerator.daily()` | 删除假图表区块（仅保留真实 breakdown） |
| `UnfollowListView.swift:14` | `[MockFollower]` | `[UnfollowEntry]` |
| `FollowerDetailView.swift:70` | `MockFollowerListGenerator().generateUnfollows()` | `viewModel.unfollowList`（外部传入） |

### 2.4 重建已删除的 Service

**GeoDistributionService** — 已删除的 class 需要重建

重建为调用 Instagram Insights API 获取 `audience_city`/`audience_country`（需 Business/Creator 账号 + ≥100 粉丝）。不满足条件时返回空结果，UI 显示 `ContentUnavailableView`。

```swift
final class GeoDistributionService: GeoDistributionServiceProtocol {
    private let apiClient: InstagramAPIClientProtocol
    private let tokenProvider: TokenProviderProtocol

    func fetchDistribution(accountId: Int64) async -> GeoDistributionResult {
        // 调 apiClient.fetchInsights(metrics: ["audience_city", "audience_country"], period: "lifetime")
        // 解析 breakdown 格式的地域数据
        // 无数据时返回 GeoDistributionResult(regions: [], isRealData: false)
    }
}
```

### 2.5 恢复已删除的 ViewModel 方法

**TrendsViewModel** — `generateHourlyData()` + `selectWindow()` 需要重建

重建为基于真实 Snapshot 数据按小时均分（不添加随机噪声）：

```swift
func generateHourlyData() async {
    guard let snap = try? await snapshotRepo.latest(accountId: selectedAccountId) else {
        hourlyData = [:]
        return
    }
    // 每种 metric 取 Snapshot 值 / 24 均分到每小时
}

func selectWindow(_ window: TimeWindow) async {
    selectedWindow = window
    if window == .day { await generateHourlyData() }
}
```

---

## 执行顺序

```
第一步（API 层 + 认证）：
  □ 1. InstagramAPIClient.swift         ← 新建
  □ 2. TokenProvider.swift              ← 新建
  □ 3. AccountViewModel.connectWithToken() ← 重写
  □ 4. AccountView Token UI            ← 重写
  □ 5. SyncEngine.sync() API 调用      ← 重写
  □ 6. DIContainer + SettingsView      ← 注入新依赖

第二步（清除假数据）：
  □ 7.  MediaPost.swift                ← 新建
  □ 8.  UnfollowEntry.swift            ← 新建
  □ 9.  GeoDistributionService 重建    ← 接入 API
  □ 10. TrendsViewModel 方法重建       ← generateHourlyData + selectWindow
  □ 11. DashboardViewModel 假数据清理  ← 删 6 处 .random() 调用
  □ 12. PostRowView/Detail/List        ← MockPost → MediaPost
  □ 13. DashboardView                  ← MockPost → MediaPost
  □ 14. EngagementDetailView           ← 删 MockEngagementGenerator 引用
  □ 15. PredictionDetailView           ← 删 Int.random 假历史
  □ 16. BestTimeView                   ← 删随机回退
  □ 17. FollowerDetailView             ← MockFollowerListGenerator → ViewModel
  □ 18. UnfollowListView               ← MockFollower → UnfollowEntry
  □ 19. TrendChart + TrendDetailView   ← 清理 Preview .random()
```

---

## 约束

- **不修改测试文件**（`FollowerTests/`、`FollowerUITests/` 中的 Mock 类保留不动）
- **不运行测试**，仅通过编译即可
- **不修改 IngestionService / AggregationService**——它们只消费 DTO，不受数据来源影响
- **不修改 TrendChart 渲染逻辑**——只改数据源，不改 View
