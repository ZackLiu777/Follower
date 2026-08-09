# Instagram App Review 计划：解决开发模式数据限制

- 状态：待实施（提交 App Review 前需先补权限）
- 日期：2026-08-09
- 关联文档：[`instagram-oauth-login-plan.md`](./instagram-oauth-login-plan.md)（登录方案）、[`project-overview.md`](./project-overview.md)（notes 20）

## 1. 问题：开发模式下扩展权限端点返回空数组

### 1.1 现象

App 内帖子有评论（帖子详情显示 comments: 6），但评论管理页显示「暂无评论」；insights 趋势图无数据。

### 1.2 实测证据（2026-08-09，真实 token 逐端点验证）

| 检查项 | 结果 |
| --- | --- |
| token 有效性（GET /me） | ✅ 200，qqiangge / MEDIA_CREATOR |
| 账号状态（GET /me/media） | ✅ 200，1 帖（`18061477577562697`，likes: 2，**comments: 6**） |
| 测试者身份 | ✅ qqiangge 为已生效的 Instagram 测试者 |
| 帖子评论（GET /{media}/comments） | ❌ **HTTP 200 + `data: []`**（空数组，非报错） |
| 账号洞察（GET /me/insights） | ❌ **HTTP 200 + `data: []`**（空数组，非报错） |

### 1.3 结论

- **开发模式（App 发布状态 = 未发布）下，未经审核的扩展权限端点对所有人返回空数组，测试者也不例外。**
- 基础端点（/me、/me/media）不受影响，因此「账号信息、帖子列表、点赞数」正常，只有评论与 insights 为空——这正是 App 里看到的症状组合。
- 空数组不是 token 问题、不是权限配置问题、不是代码 bug——`InstagramAPIClient` 的 `get()` 对 200 响应直接解码返回，`data: []` 原样透出，链路本身无异常（见 `InstagramAPIClient.swift:58-62` 与 `CommentService.swift:36`）。
- 这是 Meta 的硬限制，**无代码侧绕过**，唯一出路是把 App 切到 Live 模式。

## 2. 解决路径：提交 App Review → Live 模式

### 2.1 前置准备（必做，否则审核必被拒）

1. **补齐面板权限**（App Dashboard → Instagram → API setup with Instagram login → 权限列表）：
   - 当前列表缺 **`instagram_business_manage_insights`**——insights 返回空与此直接相关（权限未配置在 token 上）。
   - 建议审核前勾选：`instagram_business_basic`、`instagram_business_manage_comments`、`instagram_business_content_publish`、`instagram_business_manage_insights`。
   - 注意：扩展权限勾选后，**已签发的旧 token 不含新权限**，需重新授权生成新 token。
2. **准备审核素材**（App Review 要求演示每个请求权限的端到端使用）：
   - 评论管理：截图/录屏——从 App 进入帖子详情 → 查看评论列表 → 回复/删除一条评论。
   - insights：截图趋势图页面。
   - 素材必须展示「已登录真实账号 + 数据真实呈现」，纯 mock 数据截图会被拒。
3. **确认 App 本身可提交审核**：
   - App Store Connect 中 App 已创建且配置完整（名称、图标、描述、隐私政策等）。
   - 若尚未上架，App Review 可与首次提审一起进行。

### 2.2 提交流程

1. App Dashboard → Instagram → App Review（提交审核）。
2. 按 2.1 的素材逐项填写「演示视频 / 说明」。
3. 提交后等待 Meta 审核（通常 1~5 个工作日，扩展权限可能更久）。
4. 审核通过 → 发布状态变为 **Live** → 评论与 insights 端点对测试者账号立即返回真实数据。
5. 重新授权生成新 token（含全部权限）→ App 内重新连接账号 → 验证评论/insights。

### 2.3 验收标准

- [ ] 面板发布状态 = Live
- [ ] GET /{media}/comments 返回真实评论（非空数组）
- [ ] GET /me/insights 返回真实指标（follower_count 等）
- [ ] App 内评论管理页显示真实评论，回复/删除可用
- [ ] App 内趋势图显示真实数据

## 3. 与登录方案的关联

| 事项 | 文档 | 时机 |
| --- | --- | --- |
| 开发模式限制 → App Review | 本文档 | 立即（解锁评论/insights） |
| OAuth 一键登录（域名 + AASA） | `instagram-oauth-login-plan.md` | 正式发布前 |
| 面板权限补齐 + token 重签 | 本文档 2.1 | 与 App Review 同批 |

两者互不阻塞：App Review 解锁的是**数据端点**，域名方案解锁的是**登录体验**。开发阶段可先走 App Review 拿真实数据，域名方案按原计划推进。

## 4. 风险与注意

- **审核被拒**：最常见原因是素材不完整。务必提供真实账号的端到端演示，不要用 mock 截图。
- **旧 token 失效**：权限列表变更会改变 token 权限集，App 内需要重新连接账号（`AccountView` 的 Token 粘贴或 OAuth 流程均可）。
- **测试者限制**：Live 模式后普通测试者即可访问已审核权限；未审核的新权限仍会再次遇到空数组，直到再次审核通过。
