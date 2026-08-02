# UI & Premium 功能优化 + Bug 修复记录

> **日期**：2026-07-26
> **状态**：已解决

---

## 1. 已修复 Bug

### 1.1 删除账号后创建新账号 → FOREIGN KEY constraint failed

**现象**：设置 → 删除本地数据 → 重新创建账号 → 点击同步 → `SQLite error 19: FOREIGN KEY constraint failed - INSERT INTO event`。

**根因**：
1. `SettingsViewModel.deleteLocalData(accountId:)` 删除账号后，`DashboardViewModel.selectedAccountId` 仍指向已删除的旧 ID
2. 创建新账号后，`DashboardViewModel.loadAccounts()` 只在 `selectedAccountId == nil` 时才重新赋值——但旧 ID 非 nil，所以不更新
3. `viewModel.sync()` → `SyncEngine.sync(accountId: <旧 ID>)` → 尝试 INSERT event 引用不存在的 accountId → FOREIGN KEY 失败

**修复**：
1. `SettingsViewModel.deleteLocalData`：删除后判断 `selectedAccountId == accountId` → 重置为剩余账号第一个
2. `DashboardViewModel.loadAccounts`：从 `selectedAccountId == nil` 改为 `== nil || !accounts.contains(where: { $0.id == selectedAccountId })`——无论何时都确保选中的 ID 有效
3. `SyncEngine.sync()`：入口新增 `accountRepo.fetch(id: accountId)` 校验——账号不存在则静默返回空结果，不写 event

### 1.2 Premium 新增 key 不生效（themeSwitching / growthDecisions）

**现象**：解锁 Premium 后主题切换依然锁住。

**根因**：`PremiumFeatureRepository.setEnabled()` 只做 UPDATE——但 `themeSwitching` 和 `growthDecisions` 是迁移之后新增的 `PremiumFeatureKey` case，数据库中不存在对应行，UPDATE 影响 0 行。

**修复**：
1. `setEnabled` 改为 UPSERT：先 `fetchCount`，存在则 UPDATE，不存在则 INSERT
2. `AppState.refreshPremiumFlags()` 每次刷新时对每个 key 调一次 `setEnabled`，触发 UPSERT 补齐缺失 key

### 1.3 Instagram API `impressions` 指标被移除

**现象**：Sync 时 `metric[2] must be one of the following values: ...`，合法值列表不含 `impressions`。

**根因**：Instagram Graph API v25 将 account-level insights 的 `impressions` 替换为 `views`。

**修复**：`SyncEngine` 中 `["follower_count", "reach", "impressions"]` → `["follower_count", "reach", "views"]`。

### 1.4 账号重复插入 UNIQUE 约束

**现象**：同一 token 连接两次 → `SQLite error 19: UNIQUE constraint failed: account.platform, account.username`。

**修复**：`createAccountAndSync` 插入前先 `fetchAll` 查重——已存在则 `update`，不存在才 `insert`。

### 1.5 GRDB insert 返回 nil id

**现象**：`accountRepo.insert(account)` 成功但 `saved.id` 为 nil → "Failed to save account."。

**根因**：GRDB 的 `didInsert(_:)` 回调在 Swift 6 并发模式下可能不被触发。

**修复**：不再依赖 `insert` 返回值的 `.id`。改为 `insert` 后立即 `fetchAll` 从数据库回查自增 ID。

---

## 2. 新增功能

### 2.1 Premium 功能扩充

| 新增 key | 用途 |
|---------|------|
| `growthDecisions` | 增长决策 Tab（Premium 门控） |
| `themeSwitching` | 主题切换（Apple Native / Instagram，Premium 门控） |

### 2.2 设置页面 Premium 锁定

| 设置项 | Premium Key | 锁效果 |
|--------|-----------|--------|
| 主题选择器 | `themeSwitching` | 未解锁显示 🔒，禁止交互 |
| 导出格式选择器 | `csvExport` | 同上 |
| 导出数据按钮 | `csvExport` | 同上 |

### 2.3 SF Symbols 全行覆盖

所有设置行均添加 SF Symbol 图标：

| 设置项 | SF Symbol |
|--------|-----------|
| 语言 | `globe`（Picker 自带） |
| 主题 | `paintpalette.fill` |
| 导出格式 | `doc.text.fill` |
| 导出数据 | `square.and.arrow.up.fill` |
| 存储 | `lock.shield.fill` |
| 隐私政策 | `hand.raised.fill` |
| 删除数据 | `trash.fill` |
| 所有 Premium 功能（22 项） | 分别对应图标（chart / bolt / star / globe / shield / calendar / brain / icloud / flag / clock / bubble / sparkle 等） |

### 2.4 删除所有账号

「删除所有本地数据」按钮改为调用 `deleteAllAccounts()`——遍历所有账号逐个删除，清空 `accounts` 和 `selectedAccountId`。

### 2.5 Premium 功能颜色同步主题

Premium 功能列表中的图标和状态徽章颜色由硬编码 `.green` / `.secondary` 改为 `theme.positiveGreen` / `theme.textSecondary`。

### 2.6 评论管理详情页重构

`CommentManagementDetailView` 从 4 条硬编码假评论 + 3 个硬编码数字 badge 改为 `ContentUnavailableView` 占位。

### 2.7 Settings 多语言

`premium.themeSwitching` 4 语言本地化：en "Theme Switching" / ja "テーマ切り替え" / zh-Hans "主题切换" / zh-Hant "主題切換"。

---

## 3. 当前代码统计

| 模块 | 文件数 | 代码行数 |
|------|:-----:|:------:|
| `Follower/`（生产代码） | 89 | 11,956 |
| `FollowerTests/`（单元测试） | 18 | 4,311 |
| `FollowerUITests/`（UI 测试） | 9 | 956 |
| **合计** | **116** | **17,223** |

---

## 4. 未实现功能

### 需要 Instagram API 权限 + Meta App Review

| 功能 | 阻塞点 |
|------|--------|
| OAuth 登录（ASWebAuthenticationSession 自动获取 token） | Meta 需接受 `follower://` 或 `https://localhost` redirect URI；当前只能用 Token 粘贴模式 |
| Token 自动刷新（60 天过期后自动续期） | 需要定期检查 Keychain 中 token 过期时间 + 调 `/refresh_access_token` |
| 评论管理（CRUD） | `GET /{media-id}/comments` + `POST replies` + `hide/delete` — 对 25 条媒体各打 1 次 API |
| 内容排期 + 发布 | `POST /media` → `POST /media_publish` 两步 Container 流程，需 `instagram_business_content_publish` 权限（Meta App Review） |
| 竞品对比 | `business_discovery.username(target)` 仅查公开 Business/Creator 账号基础指标 |

### 需要第三方服务

| 功能 | 原因 | 候选方案 |
|------|------|---------|
| 粉丝列表（谁关注了/取关了） | Instagram API 不支持获取个体粉丝信息 | SocialDog / HikerAPI / Apify Instagram Scraper |
| 受众年龄/性别 | 仅 Business 账号 + ≥100 粉丝才有 `audience_gender_age` | Iconosquare / HypeAuditor API |

### 纯本地未实现

| 功能 | 说明 |
|------|------|
| MediaKit PDF 导出 | `PDFKit`（Apple 自带），需设计多页模板（头像 + 统计 + 图表截图 + 联系方式） |
| Data Encryption | `advancedEncryption` key 已预留，需集成 `CryptoKit` |
| Multi-Device Sync | `multiDeviceSync` key 已预留，需 CloudKit / iCloud Drive |
| Local AI Analysis | `localAIAnalysis` key 已预留，需 CreateML / Core ML 模型 |
