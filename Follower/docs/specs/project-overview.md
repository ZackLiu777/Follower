# Follower 项目总览

> **更新日期**：2026-08-07
> **分支**：delta
> **代码量**：生产 99 文件 / ~14,000 行；单元测试 19 文件 / ~4,700 行；UI 测试 9 文件 / ~1,000 行

---

## 1. 项目概览

本地优先的 Instagram 数据跟踪与分析 iOS App（SwiftUI）。用户通过 Instagram Graph API token 同步粉丝/互动数据，本地 GRDB + SQLite 存储，提供仪表盘、趋势图表、增长决策、账号设置等模块。所有数据默认仅存本地。

**技术栈**：SwiftUI（MVVM + `@Observable`）、GRDB 7.11（vendored）、SQLite、Swift Charts、Keychain、iOS 26 部署目标。

---

## 2. 架构

### 2.1 目录结构（MVVM 分层，2026-08-06 重构）

```
Follower/
├── App/                        # 入口（FollowerApp / ContentView / AppState）
├── Core/                       # 基础设施
│   ├── AppState.swift          #   全局状态（主题/语言/Premium/TabBar 折叠）
│   ├── DIContainer.swift       #   依赖注入容器
│   ├── DatabaseManager.swift   #   GRDB 数据库管理
│   ├── ThemeSystem.swift       #   主题系统（8 套 + Liquid Glass 组件）
│   ├── TrialManager.swift      #   Premium 试用管理
│   └── Localization/           #   L10n + 4 语言
├── Models/                     # 领域模型（Account/Event/Snapshot/Metric/PremiumFeature...）
├── Repository/                 # 数据访问层（唯一入口：Account/Event/Snapshot/Metric/PremiumFeature/DraftPost/MediaPost）
├── Services/                   # 业务服务
│   ├── API/                    #   InstagramAPIClient / TokenProvider + RoutingTokenProvider / OAuth / IGModels / CommentService
│   ├── Sync/                   #   SyncEngine / APIDTOs
│   ├── Ingestion/              #   API DTO → 内部模型
│   ├── Aggregation/            #   原始事件 → Snapshot / Metric
│   ├── Analysis/               #   10 个分析服务（预测/活跃度/留存/地域/质量...）
│   ├── Decisions/              #   增长决策引擎
│   ├── Export/                 #   JSON / CSV 导出
│   ├── Mock/                   #   Mock 层：SeededRandom（确定性随机）、MockInstagramAPIClient（测试账号假数据）、APIClientResolver（全局分派点）
│   └── PostAssistantService    #   发布助手（剪贴板/图片/通知/快捷指令引导）
└── Features/                   # 功能模块（每个模块 Views/ + ViewModels/）
    ├── Dashboard/   Views(16) + ViewModels(1)
    ├── Trends/      Views(2) + ViewModels(1)
    ├── Decisions/   Views(2) + ViewModels(1)
    ├── Account/     Views(2) + ViewModels(1)
    ├── Settings/    Views(1) + ViewModels(1)
    ├── Posts/       Views(2)
    └── Shared/
        ├── Components/         # AccountBar / DashboardCard / PremiumGate / StatCard / TrendChart
        └── Views/              # EmptyStateView / ErrorBanner / SplashView
```

### 2.2 数据分层（单库多表）

```
Event（append-only 原始观测）→ AggregationService → Snapshot（UI 快照）+ Metric（分析指标）
```

- **Event**：只追加，不就地修改
- **Snapshot**：可 upsert（粉丝数/互动/媒体数等）
- **Metric**：后台聚合产生（followerGrowth/engagementTrend/averageLikes...），View 不实时计算
- **JSON** 仅用于导出，不作为主存储

### 2.3 架构边界（CLAUDE.md 强制）

- View 只展示状态 + 触发交互，**不直接访问数据库**
- ViewModel 只做状态编排 + 轻量逻辑，**不做复杂 I/O**
- Repository 是**唯一数据访问入口**
- 持久化必须经过 GRDB 层

### 2.4 主题状态机

```
AppState.currentTheme（单一状态源，@Observable）
  ├─ 自定义颜色 → 所有 View 确定性读取（currentTheme.xxx，不经 environment）
  ├─ colorScheme → sheet 根注入 preferredColorScheme + .environment(\.colorScheme)
  └─ 主树环境 → ContentView.themeSynced（withTheme 注入 @Environment(\.theme)）
```

`currentTheme` didSet 状态机：`transitioning → 广播 themeChanged → synced`（见 `docs/specs/theme-switch-sync-fix.md`）。

---

## 3. 已实现功能

### 3.1 账号与同步
- ✅ Token 粘贴创建账号（Keychain 存储，`IGAA` token）
- ✅ OAuth 登录（ASWebAuthenticationSession，`https://localhost/oauth/callback`）
- ✅ 真实 API 管线：`/me` + `/me/insights`（follower_count/reach/views）+ `/me/media`（25 条）并行请求 → Ingestion → Aggregation → Metric
- ✅ 多账号管理（切换/删除/查重 upsert）
- ✅ 深色模式开关 + 主题选择器（Premium 门控）

### 3.2 仪表盘
- ✅ 右上角 Liquid Glass 头像（点击 → 个人账号弹窗）
- ✅ 最近内容（帖子列表 + 详情）
- ✅ 指标卡片（互动率/帖子数，竖向 Liquid Glass，含赞/评论/分享/曝光/平均）
- ✅ Premium Insights（16 项，连续滚动双列 Liquid Glass 网格）
- ✅ 多账户快速切换菜单

### 3.3 发布助手（Premium: contentScheduling）
- ✅ Composer（PhotosPicker 选图 + 文案 + 排期开关），三种流程：保存草稿 / 排期提醒 / 立即发布
- ✅ 立即发布：文案复制剪贴板 + 系统分享面板分享图片 → Instagram 粘贴发布（零 API 依赖）
- ✅ 排期：本地通知提醒（UNUserNotificationCenter），App 无法后台准点发布——到点提醒 + 用户确认
- ✅ 发布队列（PostQueueView）：草稿/排期中/已发布/已取消 分组，到期高亮「待发布」，滑动删除清理图片
- ✅ 快捷指令引导页（shortcuts:// 跳转 + 使用说明）
- ✅ DraftPost 数据层（GRDB 表 + MigrationV2 + Repository）

### 3.4 评论管理（Premium: commentManagement）
- ✅ Business API 端点（graph.facebook.com）：拉取 / 回复 / 删除评论，POST/DELETE 支持
- ✅ 帖子详情页评论入口 → CommentListView（回复输入 + 滑动删除 + 错误友好提示）
- ✅ 仅 BUSINESS/CREATOR 账号可用：`/me` 注入 account_type 并持久化到 Account，个人账号显示明确提示
- ✅ CommentService（协议 + 实现，DIContainer 注入）

### 3.5 趋势
- ✅ 日/周/月/年 四窗口图表（粉丝/互动/点赞/评论/分享/浏览）
- ✅ 总览页每卡片 `+/-` 增减徽章（末值−首值，theme.accentPrimary）
- ✅ 详情页：总计（求和）+ 周期标签（今天/本周/年月/年份下拉）
- ✅ 详情页窗口与总览页同步（init 继承 selectedWindow）
- ✅ 年份维度（账号创建年 → 当前年，year 模式下拉切换）

### 3.6 决策
- ✅ Growth Decision Engine（Premium 门控，全屏 UpgradePromptView）
- ✅ 时间线流 UI（分类色 + Liquid Glass 卡片）

### 3.7 Premium
- ✅ 22 个 PremiumFeatureKey 门控（UPSERT 持久化）
- ✅ Master Toggle 状态机（ON 全解锁 / OFF 全锁定 / partial 中间态）
- ✅ Trial 试用（自动解锁 + 剩余时间）
- ✅ PremiumGate sheet（75% 高度，无小横条）

### 3.8 设置
- ✅ 个人账号弹窗（Form + Section，64pt 统一行高）
- ✅ 语言（4 语言）、深色开关、主题选择（8 套）、数据导出（JSON/CSV）、存储、隐私、删除数据
- ✅ 删除所有账号（级联清理）

### 3.9 分析服务（真实计算，数据为空时显示空状态）
- ✅ 粉丝增长预测（线性回归）、活跃度分析、留存/流失、地域分布、互动质量评分、竞品对比、互动热力图、投放效果跟踪、真实性评估、最佳发帖时间、内容策略

### 3.10 UI 系统
- ✅ 8 套主题（Apple Native/Instagram/Apple Dark/Forest/Mono Stone/星云紫/Instagram Dark/羊皮纸白）
- ✅ Liquid Glass 玻璃卡片（4 层：材质+充填+光晕+实线；深色显示白线，浅色取消）
- ✅ Scroll Edge Effect（.soft，5 个页面）
- ✅ TabView 滚动隐藏为小圆形图标（⋯，Liquid Glass 圆钮）
- ✅ 主题切换同步状态机（自定义色 + colorScheme 双通道）
 
---

## 4. 未实现 / 待办

### 4.1 需要 Meta 权限 / App Review
| 功能 | 阻塞点 |
|------|--------|
| OAuth 完整可用 | Meta 平台配置（App ID `4714425505453589`）；当前 Token 粘贴兜底 |
| Token 自动刷新 | 60 天过期后调 `/refresh_access_token` |
| 竞品对比 | `business_discovery` 需权限 |

> **已落地替代方案**：内容发布/排期改用系统分享面板 + 快捷指令（见 3.3，零 API 依赖）；
> 评论管理已用 Business API 实现（见 3.4），前提是账号为 BUSINESS/CREATOR。

### 4.2 需要第三方服务
| 功能 | 候选 |
|------|------|
| 粉丝列表（谁关注/取关） | SocialDog / Apify 等 |
| 受众年龄/性别 | Iconosquare / HypeAuditor |

### 4.3 纯本地未实现
| 功能 | 说明 |
|------|------|
| MediaKit PDF 导出 | UI 壳保留 |
| 本地 AI 分析 | 规则引擎占位 |
| 高级加密 / 多设备同步 | 仅预留 key |

---

## 5. UI 风格规范

1. **Liquid Glass 玻璃卡片**（`FollowerGlassModifier`，Shared/Components/DashboardCard.swift）：
   - 深色主题：材质（或静态填充）+ 垂直充填 + 实线边缘高光，**无阴影**（黑色投影在深背景不可见）
   - 浅色主题：仅材质 + 充填，**无白线、无阴影**
   - **性能策略**：光晕 blur 羽化层已移除（滚动每帧重渲主源）；阴影层整体移除；`usesMaterial: false` 时毛玻璃材质 → 静态半透明填充（零采样）——滚动路径的小卡片/tile（如 Dashboard Premium 网格 16 张）必须用静态版，大卡保留材质
2. **图标**：18~20pt，`theme.accentPrimary`；头像 44pt（纯 icon + Material 圆底 + 白描边）
3. **卡片行高统一 64pt**，`listRowInsets(0,16,0,16)`
4. **文字**：浅色主题 `textPrimary: .black.opacity(0.85)`（纯黑散光）；行标签 subheadline、次级 caption
5. **背景**：主题三色渐变（纯色主题如羊皮纸白用同色数组）
6. **导航栏头像**：32pt 纯图标（toolbar 安全尺寸，禁 Material 叠层）
7. **禁止**：toolbar 内放 Spacer/Menu/sheet、卡片内混系统色（.green/.red）、动态色（.secondary/.primary）存入 Theme

---

## 6. 注意事项

1. **主题切换**：sheet 是独立 presentation root——弹窗内容必须显式注入 colorScheme（`preferredColorScheme` + `.environment(\.colorScheme)`），详见 `theme-switch-sync-fix.md`
2. **调试代码**：`AppState.currentTheme` didSet 与 SettingsView body 有 `[ThemeDebug]` print（`#if DEBUG`）——验证完成后可删
3. **测试状态**：
   - 确定性测试（Models/Theme/Localization/Lambda/PremiumServices/DecisionsEngine/TrendChart/Phi/AppState/Follower）CI 必须通过
   - 共享 DB / @MainActor VM / UI timing 类测试（Repository/Services/AccountViewModel/TrendsViewModel/Gamma/PremiumSync 等）允许失败
   - UI 测试依赖模拟器（GitHub Actions runner 曾缺 iPhone 17 Pro 设备——环境问题非代码问题）
4. **ThemeTests.testBackgroundGradientColors**：Color Equatable 跨 iOS 版本不可靠，用 RGBA 分量近似比较（`UIColor(Color)` 解析）
5. **Glass.swift**（参考示例）在 `docs/reference/`，不参与编译；其命名（LiquidGlassModifier/liquidGlassEffect）与生产（FollowerGlassModifier/followerGlassEffect）不冲突
6. **Mock 目录**（Services/Mock）：仅供测试/预览兼容（PostType 定义），生产代码不引用
7. **GitHub Actions**：unit-tests 用 `macos-26` runner，destination `name=iPhone 17 Pro`——若遇 "Unable to find a device"，需在 CI 加模拟器预创建步骤（runner 池不一致）
8. **性能**：列表用 Lazy 组件、批量写批处理、指标卡/图表懒加载——保持
9. **发布助手能力边界**：App 无法程序化触发快捷指令（`AppIntents` 是反向的）；最终发布必须用户在 Instagram 内确认；「排期」= 到点本地通知提醒 + 一键预填（文案已在剪贴板），不是后台自动发布——UI 与文档必须按「发布助手」而非「自动排期」表述
10. **评论管理**：仅 BUSINESS/CREATOR 账号可用（`account_type` 已随 `/me` 持久化到 Account）；API 报 400+permission 时 UI 给出切换商务账号提示；评论端点与主数据同域 `graph.instagram.com/{media-id}/comments`（2024 年 Basic Display 停用后，Instagram Login token 已带 instagram_business_* 权限，无需 Facebook 域 EAAB token）
11. **DraftPost 图片存储**：沙盒 `Documents/FollowerDrafts/`，删除草稿时必须同步 `deleteImage` 清理文件，避免沙盒残留
12. **测试账号（Test tab → 用测试数据连接）**：创建 `isTest=true` 账号 + 哨兵 token（`mock://token`）→ 全链路 Mock 同步（730 天序列 / 25 条媒体 / 评论 / 地域分布），无需真实 Token/OAuth；测试账号显示「测试」徽章，可多个（test.user / test.user.2 / ...）。**token 经 `RoutingTokenProvider` 分派**：测试账号不落 Keychain（`storeToken` no-op，连接永不因 Keychain 失败；`getToken` 一律返回哨兵，兼容历史坏账号），真实账号原样走 Keychain
13. **Mock 分派契约**：`APIClientResolver` 是唯一分派点——哨兵 token（`mock://` 前缀）→ MockInstagramAPIClient，其余（真实 IGAA…/EAAB… token）→ 真实 API；真实 token 由 Meta 颁发，格式上不可能含 `mock://`，因此测试数据只能进测试账号（方向安全）；`Account.isTest` 仅做 UI 语义（徽章），不参与分派；Mock 数据确定性（seed=42 LCG），同 seed 同结果可断言
14. **测试库隔离**：Repository 类测试用 `DatabaseManager(inMemory: true)`（内存库），不写磁盘、用例间不污染（DraftPostTests 已迁移）
15. **批量写入性能**：`MetricRepository.upsertBatch` 用 INSERT OR REPLACE（依赖唯一索引 idx_metric_account_type_window，~5000 条/次 sync）；`SnapshotRepository.upsertBatch` 用 DELETE+INSERT（snapshot 表无唯一索引——历史重复行会使加唯一索引的迁移失败）。均去掉逐条前导 SELECT，同步耗时从秒级降到毫秒级
16. **历史互动数据**：Mock `fetchInsights` 附加返回 likes/comments/shares 日频序列（独立 rng 副本生成，不扰动主序列形态）；`APITrendDataPoint.likesCount/commentsCount/sharesCount` 为 Optional（旧 Event payload 缺 key 解码不失败）；真实 API 不请求这三个指标 → nil → 0，行为不变
17. **Dashboard 滚动性能**（滑动掉帧优化）：glass 光晕 blur 羽化层 + 阴影层移除、`usesMaterial: false` 静态填充版（滚动路径小卡片/tile 必须用，深色模式 material 每帧重采样是掉帧主因）（见 UI 规范 1）；滚动容器 `VStack → LazyVStack`（3 个 Section 离屏释放）；`updateSyncState()` 从 body 移出（body 内无条件写 @Observable 属性 → 每次求值通知订阅者），改由 onChange 驱动 + 值保护（`AppSyncState: Equatable` 相同状态不写）
18. **帖子持久化（MigrationV4，media_post 表）**：MediaPost 原仅存 SyncEngine 内存缓存，App 重启后 Dashboard 最近内容消失；v4 起 sync 时经 `MediaPostRepository.upsertBatch` 落库（igMediaID 唯一键 → 重复同步替换），`fetchRecentMedia` 内存缓存优先 + 读库兜底回填；删账号外键级联清理；落库失败不阻塞 sync 主流程
19. **帖子图片展示**：`fetchMedia` 请求 `media_url,thumbnail_url` → `IGMedia.mediaURL/thumbnailURL`（缺 key 解码为 nil 兼容旧响应）→ `displayImageURL` 选择规则（VIDEO 用封面缩略图——media_url 是视频文件；IMAGE/CAROUSEL 用原图，互缺时兜底）→ 落库 `MediaPost.mediaURL`；UI 用共享组件 `PostImageView`（AsyncImage + phase 降级：无 URL/加载失败/加载中 → 类型色块+图标，PostRowView 48pt 缩略图 / PostDetailView 260 大图）；Mock 数据无真实图片（本地优先）→ nil 走色块降级；图片从 IG CDN 拉取仅下行展示，不违反"数据不上传云端"
20. **评论端点同域修复**（评论无法显示根因）：旧实现评论走 `graph.facebook.com/v21.0`（Facebook 域），而 App 的 token 是 Instagram Login 签发的 IGAA token（`api.instagram.com` 交换）——跨域 token 必被 Meta 拒绝（OAuthException 190），评论永远无法显示且与权限配置无关；2024 年 Basic Display 停用后评论端点已并入 `graph.instagram.com`（与主数据同域同 token），现全部评论方法（fetch/reply/delete）改走 `baseURL`，删除 facebookBaseURL 与 v21.0 版本号；新 API **不返回 username 字段**（fields 只用 id,text,timestamp，UI 兜底「Instagram 用户」）；`CommentViewModel.friendlyError` 解析 Meta 错误码（190→重新连接引导 / 200→商务账号提示 / 10→Meta 平台权限引导），`metaErrorCode` 为 nonisolated 纯函数；注意：Meta 开发模式下评论接口返回空数组（非报错）——正式使用需把 App 切到 Live 模式
21. **2026 Instagram API 现状与 OAuth 端点迁移**：个人账号已完全不可用（2024-12-04 Basic Display 停用后官方 API 不支持个人账号），账号必须切专业账号（创作者/商务）；**Creator 账号走 Instagram Login 路径（graph.instagram.com）无需链接 FB 主页**（需 FB 主页的是 Business API graph.facebook.com 路径）；OAuth 授权端点已从 `api.instagram.com/oauth/authorize` 迁移到 **`www.instagram.com/oauth/authorize`**（token 交换仍走 `api.instagram.com/oauth/access_token`，长期 token `graph.instagram.com/access_token` 不变）——`InstagramOAuthConfig.authorizeURL` 已更新并有断言测试；手动粘贴 token 需注意 Meta token 可能被复制截断（错误 190 "Cannot parse access token"），推荐用 App 内 OAuth 登录生成

---

## 7. 相关文档索引

- `docs/specs/instagram-api-integration-plan.md` — API 集成方案
- `docs/specs/instagram-api-pitfalls.md` — API 踩坑记录
- `docs/specs/ui-premium-bugfix.md` — UI/Premium bug 修复
- `docs/specs/dashboard-refactor-and-settings-migration.md` — 仪表盘重构 + 设置迁移
- `docs/specs/dashboard-header-overlap-fix.md` — 导航栏头像重叠 + 设计系统统一
- `docs/specs/theme-switch-sync-fix.md` — 主题切换同步修复
- `docs/reference/Glass.swift` — Liquid Glass 参考实现
