# Instagram OAuth 登录正式方案（域名 + AASA 回调）

> **日期**：2026-08-08
> **状态**：方案评审中（待实施）
> **目标**：让终端用户用「一键授权」登录 App（与微信/Google 登录同级别体验），替代当前仅开发者可用的 Token 粘贴与手动回填流程

---

## 1. 背景：为什么需要这个方案

### 1.1 约束链（2026 年现状）

App 内 OAuth 登录受 Meta 与 Apple 两侧平台限制叠加，当前组合在**真机**上无法全自动完成：

| # | 约束 | 来源 |
|---|------|------|
| 1 | Instagram 面板只接受 `http(s)://` 开头的 redirect_uri，**拒绝自定义 scheme**（`follower://` 会被拒：*"You must enter an absolute URI that starts with http:// or https://"*） | Meta |
| 2 | `ASWebAuthenticationSession` 旧 API 的 `callbackURLScheme` **只拦截自定义 scheme**，https 跳转一律不拦截（回调跳转到 localhost 后加载失败 → 错误 1 CanceledLogin） | Apple |
| 3 | iOS 17.4+ 新 API `.https(host:path:)` 可拦截 https 回调，但**必须配置 webcredentials Associated Domains + 托管 AASA 文件**；**真机校验严格**（模拟器宽松） | Apple |
| 4 | 当前回调地址 `https://localhost/oauth/callback` 无域名、无法托管 AASA | — |

**结论**：`ASWebAuthenticationSession 全自动 OAuth` + `localhost 回调` 在真机无解。同行做法对比：主流社交管理工具（Later/Buffer 等）均为 SaaS——回调到自有服务器、token 存云端，与本项目「本地优先」约束冲突；Basic Display 时代的 WKWebView 拦截方案已随 2024-12 API 停用而封死。

### 1.2 方案定位

本项目坚持本地优先（数据不上云），因此选用**最小侵入方案**：仅引入一个**域名 + 静态托管 AASA 文件**，让 Apple 系统认可 `https://<域名>/oauth/callback` 为合法的 App 回调地址。**全程无后端服务器**，token 交换与数据存储仍在 App 本地完成。

---

## 2. 方案原理

### 2.1 AASA 文件（唯一需要托管的内容）

`apple-app-site-association`（AASA）是一个静态 JSON，声明"该域名的回调 URL 归属于哪个 App"：

```json
{
  "applinks": {},
  "webcredentials": {
    "apps": ["ABCDE12345.com.yourcompany.follower"]
  }
}
```

- 格式：`[Apple Team ID].[App Bundle ID]`
- 托管位置：`https://<域名>/.well-known/apple-app-site-association`
- **无任何业务逻辑**——只作身份声明，免费静态托管即可

### 2.2 完整流程（技术视角）

```
① 用户点「用 Instagram 登录」
   ↓
② App 构造授权 URL：
   redirect_uri = https://<域名>/oauth/callback   ← 已注册进 Meta 面板
   ↓
③ ASWebAuthenticationSession 弹出系统浏览器（共享 Safari cookie，SSO 正常）
   ↓
④ 用户登录 Instagram → 点授权
   ↓
⑤ Instagram 302 跳转 → https://<域名>/oauth/callback?code=XXX
   ↓
⑥ iOS 系统检测：跳转匹配【关联域 webcredentials:<域名>】
   → 在请求发出前拦截跳转，浏览器自动关闭
   ↓
⑦ App 的 completion handler 收到完整回调 URL → 提取 code
   ↓
⑧ App 本地完成交换（无需服务器）：
   POST api.instagram.com/oauth/access_token   → 短期 token
   GET  graph.instagram.com/access_token       → 60 天长期 token
   ↓
⑨ token 存 Keychain → App 直接拉 /me、/me/media、/me/insights
   ↓
⑩ 60 天后 refresh_access_token 自动续期（用户无感）
```

**第 ⑥ 步说明**：拦截发生在跳转发出之前，`<域名>/oauth/callback` 甚至不需要真实存在。实际部署时仍放一个"授权完成，请返回 App"的静态提示页，避免系统拦截延迟时用户看到白页。

### 2.3 用户视角

与微信/Google 登录完全一致：**点「用 Instagram 登录」→ 授权页点授权 → 自动回 App → 完成**。无复制粘贴、无 token 概念。

---

## 3. 落地步骤

### 3.1 准备清单

| # | 准备项 | 说明 | 成本 |
|---|--------|------|------|
| 1 | **域名**（如 `auth.follower.app`） | 注册 + DNS 解析到静态托管。也可先用 Cloudflare Pages / GitHub Pages 免费子域名（`xxx.pages.dev`）过渡 | 免费 ~ ¥50-100/年 |
| 2 | **静态托管** | 托管 AASA 文件 + 回调提示页，自动 HTTPS。GitHub Pages / Vercel / Cloudflare Pages 均可 | 免费 |
| 3 | **Xcode 配置** | Signing & Capabilities → Associated Domains → 添加 `webcredentials:<域名>` | 免费 |
| 4 | **Meta 面板** | Instagram 产品 → Business login settings → OAuth redirect URIs 改为 `https://<域名>/oauth/callback`（替换 localhost 条目） | 免费 |

### 3.2 代码改动（`Follower/Services/API/InstagramOAuthService.swift`）

1. `InstagramOAuthConfig.redirectURI` 使用新域名；
2. `requestAuthorizationCode` 改用 iOS 17.4+ 新初始化器（部署目标 26.0，无需 availability 判断）：

```swift
let session = ASWebAuthenticationSession(
    url: authURL,
    callback: .https(host: "auth.follower.app", path: "/oauth/callback"),
    completionHandler: { callbackURL, error in
        // 与原逻辑一致：解析 code
    }
)
```

### 3.3 验证步骤

1. 浏览器访问 `https://<域名>/.well-known/apple-app-site-association` 确认可读、内容正确；
2. Meta 面板确认 redirect_uri 已生效（浏览器走一次授权 URL，不再报 Invalid redirect_uri）；
3. 真机运行 App 走完整登录：授权页 → 授权 → 自动回 App → 账号创建成功；
4. 回归：现有 Token 粘贴登录不回归。

---

## 4. 正式上线登录方案

### 4.1 登录方式的三个演进阶段

| 阶段 | 适用对象 | 登录方式 | 用户操作 |
|------|---------|---------|---------|
| 测试期（现在） | 开发者/测试者 | Token 粘贴（TokenProvider 已有）或手动回填 code | 开发者面板拿 token |
| Beta（域名就绪后） | 少量真实用户 | 一键 OAuth（本方案） | 授权一次 |
| 正式发布 | 所有用户 | 一键 OAuth + App Review | 授权一次 |

**Token 粘贴不可作为正式用户登录方式**：普通用户无 Meta 开发者面板访问权，无法获取 token。

### 4.2 正式版用户侧所需

- 一个 Instagram **专业账号**（Creator/Business）；
- 点一次「用 Instagram 登录」并确认授权。

**无需**：token、开发者面板、任何技术操作。

### 4.3 权限与分发

| 场景 | 要求 |
|------|------|
| 仅自用/小范围（面板加测试用户） | 无需 App Review；在面板「身份」中将测试账号分配为 Instagram 测试人员 |
| 公开分发（App Store） | 需提交 Meta **App Review**（权限 + 合规），再走 App Store 审核 |

### 4.4 Token 生命周期

- 授权 → 短期 token → 长期 token（**60 天**）；
- 续期：`GET graph.instagram.com/refresh_access_token?grant_type=ig_refresh_token&access_token=...`（要求 token 存在 ≥24 小时、未过期、用户授予 `instagram_business_basic`）；App 本地自动续期，用户无感；
- 用户可在 Instagram 设置中撤销授权 → App 收到 190 错误 → 引导重新登录。

---

## 5. 风险与取舍

| 风险 | 影响 | 缓解 |
|------|------|------|
| `client_secret` 内置 App，可被反编译 | 凭据泄露 | 个人工具场景可接受；正式公开分发时评估「服务器下发动态 secret」或转 SaaS 架构 |
| 域名为登录链路的单点依赖（续费/AASA 在线） | 登录中断 | 域名到期前续费提醒；AASA 托管于高可用静态托管；保留 Token 粘贴作为降级通道 |
| Meta App Review 不确定性 | 公开分发受阻 | 提前熟悉权限申请流程；必要时以「仅自用」模式长期运行 |
| 60 天 token 过期后的静默刷新失败 | 用户需重新授权 | 刷新失败时友好提示 + 一键重新授权 |

---

## 6. 与项目约束的一致性

- **本地优先**：token 交换、数据拉取、存储全部在 App 本地完成；域名仅托管静态 AASA 文件，不承载任何用户数据 ✅
- **MVVM / 分层**：仅改动 `InstagramOAuthService`（Service 层），ViewModel/View 不动 ✅
- **测试**：新增/修改 OAuth URL 构造与回调解析逻辑时同步补单元测试 ✅
- **文档**：本方案即文档；实施完成后更新 `docs/specs/project-overview.md` 相关 notes
