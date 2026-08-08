# Instagram API 接入踩坑记录

> **日期**：2026-07-25
> **状态**：已解决

---

## 1. OAuth 认证配置

### 1.1 "Invalid platform app"

**现象**：ASWebAuthenticationSession 弹出 Instagram 授权页后显示「申请无效：Invalid platform app」。

**根因**：Meta 应用未配置对应平台的 Bundle ID。Instagram OAuth 要求应用在 Meta Developer Portal 中至少配置一个平台（iOS/Android）。

**解决**：
1. 进入 https://developers.facebook.com/apps/{APP_ID}/settings/
2. 「添加平台」→ 选择「iOS」
3. Bundle ID 填入 `ZaneLiao.Follower`
4. 确认 Instagram 测试者已接受邀请（「角色」→「Instagram 测试者」状态不能是「待添加」）

### 1.2 自定义 scheme 被拒

**现象**：Meta 后台「有效的 OAuth 重定向 URI」填入 `follower://oauth/callback` 时报错「should represent a valid URL」。

**根因**：Meta 不再接受自定义 URL scheme 作为 redirect URI，只接受 `https://` 开头。

**解决**：改用 `https://localhost/oauth/callback`。此 URI 仅在 OAuth 流程中用于回调拦截，不需要真正部署 localhost 服务。ASWebAuthenticationSession 会在此 URL 被请求时自动截获回调。

---

## 2. Token 获取与验证

### 2.1 Graph API Explorer 生成的是 Facebook Token 而非 Instagram Token

**现象**：粘贴 token 后 App 报 `HTTP 400: Invalid OAuth access token - Cannot parse access token`，但同一 token 在 curl 中调用 `graph.instagram.com/me/media` 却能通。

**根因**：Graph API Explorer 默认生成的是 Facebook User Token（`EAB...` 开头），而我们的 API 层调用的是 `graph.instagram.com`，只认 Instagram Token（`IGAA...` 开头）。

**解决**：
1. Graph API Explorer 中「用户或公共主页」下拉必须选 Instagram 商业账号（不是「用户口令」或「应用口令」）
2. 正确生成的 token 以 `IGAA` 开头
3. 验证：`curl "https://graph.instagram.com/me?fields=username&access_token=IGAA..."` 应返回用户信息

### 2.2 SecureField 的 `.textContentType(.password)` 干扰粘贴

**现象**：Token 已确认有效（curl 能通），但 App 始终报 token 解析错误。

**根因**：`SecureField` 设置了 `.textContentType(.password)`，iOS 密码管理器在粘贴长 token 时可能自动截断或补全，导致传入 API 的 token 不完整。

**解决**：移除 `.textContentType(.password)`，保留 `.autocapitalization(.none)` 和 `.disableAutocorrection(true)`。

---

## 3. 数据库 UNIQUE 约束冲突

### 3.1 重复创建同一 Instagram 账号

**现象**：`SQLite error 19: UNIQUE constraint failed: account.platform, account.username`。

**根因**：`account` 表在 `(platform, username)` 上有唯一索引。用户重复粘贴同一 token → API 返回相同 username → 再次 INSERT → 约束冲突。

**解决**：`createAccountAndSync` 中先查重——用 `fetchAll` 检查是否存在同 `(platform, username)` 的账号，存在则执行 `update`（刷新 token 和授权状态），不存在才 `insert`。

### 3.2 GRDB insert 返回的 id 为 nil

**现象**：`insert` 成功但 `saved.id` 为 nil → guard 失败 → 显示 "Failed to save account."。

**根因**：GRDB 的 `didInsert(_:)` 回调在某些情况下（尤其是 iOS 26 模拟器 + Swift 6 并发模式下）可能不被触发的边界情况，导致 `id` 字段未被回填。

**解决**：不依赖 `insert` 返回值的 `.id`。改为 `insert` 后立即 `fetchAll` 从数据库回查自增 ID。

```swift
// ❌ 旧代码
let saved = try await accountRepo.insert(account)
guard let accountId = saved.id else { return }

// ✅ 新代码
_ = try await accountRepo.insert(account)
let refreshed = try await accountRepo.fetchAll()
guard let found = refreshed.first(where: { $0.username == username }),
      let accountId = found.id else { return }
```

---

## 4. 代码架构

### 4.1 connectWithToken 和 connectWithInstagram 两条重复路径

**现象**：OAuth 登录能正常创建账号，但 Token 粘贴模式始终报 "Failed to save account."。修了 `createAccountAndSync` 不生效。

**根因**：`connectWithToken()` 没有调用公共的 `createAccountAndSync()`，而是 inline 了一份旧的插入逻辑——两套不同的 account 创建代码并存。

**解决**：两个入口统一调用 `createAccountAndSync(token:, username:)`，消除重复逻辑。

**教训**：重构时一定要全局搜索相同模式的代码，不能靠肉眼判断"这里应该已经改过了"。

### 4.2 Xcode DerivedData 缓存旧产物

**现象**：修改了代码中的错误文案，但运行时仍显示旧文案。

**根因**：Xcode 增量编译使用了缓存的中间产物，未重新编译修改过的文件。

**解决**：`rm -rf ~/Library/Developer/Xcode/DerivedData/Follower-*` 清理后全新编译。

---

## 5. Instagram API 变更

### 5.1 `impressions` 指标被移除

**现象**：Sync 时报错 `metric[2] must be one of the following values: ...`。错误信息列出合法值包含 `views`、`reach`、`total_interactions` 等，但没有 `impressions`。

**根因**：Instagram Graph API v25 移除了 `impressions` 作为 account-level insights 指标。其在 media-level insights 中仍可用，但通过 `/me/insights` 请求账号级 insights 时不再支持。

**解决**：将 SyncEngine 中 `apiClient.fetchInsights(metrics: ["follower_count", "reach", "impressions"], ...)` 改为 `["follower_count", "reach", "views"]`。`buildTrend` 中的 `parse("impressions")` 同步改为 `parse("views")`。

---

## 总结

| # | 类别 | 问题 | 根因 | 解决 |
|---|------|------|------|------|
| 1.1 | OAuth | Invalid platform app | Meta 未配 iOS 平台 | 添加 iOS 平台 + Bundle ID |
| 1.2 | OAuth | 自定义 scheme 被拒 | Meta 只接受 https URI | 改用 `https://localhost/oauth/callback` |
| 2.1 | Token | Token 格式不匹配 | 用错了 Facebook Token | 选 Instagram 商业账号生成 token |
| 2.2 | Token | 粘贴的 token 被修改 | SecureField textContentType | 移除 `.textContentType(.password)` |
| 3.1 | DB | UNIQUE 约束冲突 | 重复插入同账号 | 先查重再 insert/update |
| 3.2 | DB | insert 返回 nil id | GRDB didInsert 边界行为 | insert 后 fetchAll 回查 |
| 4.1 | 架构 | Token/OAuth 两条路径不同 | connectWithToken 未调用公共方法 | 统一到 createAccountAndSync |
| 4.2 | 构建 | 代码修改不生效 | DerivedData 缓存 | 清理重新编译 |
| 5.1 | API | metric[2] 非法 | impressions 已从 API 移除 | 改用 views |
