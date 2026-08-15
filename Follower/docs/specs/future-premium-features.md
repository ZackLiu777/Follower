# Spec: 候选新 Premium 功能（5 项）— 描述、实现原理与注意点

> 状态：规划中（v1.10）
> 背景：内容排期（contentScheduling）已恢复（v1.10 撤销删除决定）。
> 本文档描述 5 个可落地的新功能，供实现时参考。

## 已实现能力盘点（与 PRD 对照）

| PRD 需求 | 项目现状 |
|---|---|
| 突破 90 天长期数据看板 | ✅ v1.1 已放开（本地累积，API 仅 90 天上限） |
| Media Kit 报表导出 | ✅ mediaKitExport（PDF） |
| 评论管理 | ✅ manage_comments 读/回/删 |
| 多账号管理 | ✅ 多账号切换 |
| 深度数据分析 | ✅ 预测/最佳时间/内容档案/互动漏斗/热力图等 |

**API 权限现状**：`instagram_business_basic` / `manage_comments` / `content_publish` / `manage_insights`。
**缺**：`instagram_business_manage_messages`（私信）。

---

## A. 评论触发私信（Comment-to-DM）

### 描述
用户在帖子/Reels 评论中触发关键词（如 "PRICE"/"SEND"）→ 自动发送预设私信（含链接/促销码）。PRD Must Have、ROI 最高（DM 打开率 90%；1 分钟响应转化率比 30 分钟高 391%）。

### 实现原理
```
评论轮询（本地无 Webhook → 轮询替代）
  ↓ fetchComments（已有端点，manage_comments 权限 ✓）
  ↓ 关键词匹配（本地规则表）
  ↓ 触发私信：POST /{ig-id}/messages（需新增端点 + manage_messages scope）
  ↓ 24h 窗口校验 + 200/h 限流队列
```

### 注意点（合规红线）
1. **24 小时窗口**：仅能向过去 24h 内与账号互动的用户发私信；本地记录每用户最后互动时间戳，超窗拦截。
2. **速率限制**：约 200 条/小时（滚动窗口）——内置 Pacing Cap（滚动队列平滑发包），杜绝瞬时峰值。
3. **评论私信上限**：单帖评论触发私信最多 750 条/小时，超出排队。
4. **OAuth**：需新增 `instagram_business_manage_messages` scope（Meta 人工审核）。
5. **合规**：只走官方 Graph API；禁止 Cold DM、禁止模板化完全一致文案（建议动态文本变体：插入用户名/同义词）。
6. **架构**：本地轮询（无服务器），节奏建议 5-10 分钟/次；权限申请期间功能保持"未授权"空态。

---

## B. 内容→增长归因（Content-to-Growth Attribution）

### 描述
回答"什么内容真正涨了粉"：每篇帖子发帖后 7 天窗口的涨粉归因，聚合出 类型 × 时段 × 爆款与否 的"涨粉贡献矩阵"。

### 实现原理
```
MediaPost（发布时间） + Snapshot（日频粉丝）
  ↓ 对每篇帖子：定位发帖日 → 计算发帖后 N=7 天窗口的粉丝增量
  ↓ 归因规则（确定性）：
      - 同一窗口多篇帖子 → 按各帖互动权重分摊（或简单：日均增量摊到当日帖子）
  ↓ 聚合：类型 × 星期 × 小时 × 是否爆款 → 贡献矩阵
  ↓ 输出："Reels 贡献 68% 涨粉；周三发布平均比周日多 +18 粉"
```

### 注意点
1. **归因是相关性，非因果**：UI 需注明"估算/相关性"（与决策引擎收益一致的口径）。
2. **重叠窗口**：相邻帖子窗口重叠 → 明确分摊规则（确定性可测）。
3. **冷启动**：帖子 < 5 或快照 < 7 天 → 返回 nil，UI 走空态。
4. **零 API 依赖**：纯本地计算，无合规风险——最高优先级、最低风险。

---

## C. Reels 深度分析

### 描述
Reels 完播率 / 平均观看时长 / Saves / Shares 权重分析（推荐算法核心驱动）。

### 实现原理
```
新增 API 端点：GET /{media-id}/insights?metric=plays,reach,saved,shares,avg_watch_time
  ↓ 映射为 ReelsPerformance（单帖深度指标）
  ↓ 聚合：完播率（avg_watch_time/时长）、Saves 与 Shares 权重分析
```

### 注意点
1. **权限**：需 `instagram_manage_insights`（已有）+ 每帖 insights 端点（新增）。
2. **视频时长**：IGMedia 需新增 `media_duration` 字段（fetchMedia fields 参数扩展）。
3. **开发模式**：insights 可能返回空数组（项目已知 note 20）——空态兜底。
4. **mock 数据**：MockInstagramAPIClient 需补充 Reels 深度指标生成。

---

## D. 九宫格视觉预览（Visual Grid Planner）

### 描述
个人主页 3×3（可扩展 6×6）网格预览：调整最近帖子排列，预览主页视觉一致性。纯前端。

### 实现原理
```
MediaPost（mediaURL/占位色块）
  ↓ 自定义 GridView（SwiftUI LazyVGrid）
  ↓ 长按拖动排序（onDrag/onDrop）
  ↓ 实时预览 + 保存排序偏好（本地 UserDefaults 或内存）
```

### 注意点
1. **排序持久化**：仅本地偏好（不改 API/不改真实主页顺序——Meta 不允许第三方改排列）。
2. **占位降级**：无图帖子用类型色块+图标（复用 PostImageView 逻辑）。
3. **性能**：100 帖内直接全渲染；大账号分页。
4. **纯前端零 API**：低风险，可快速交付。

---

## E. Link-in-Bio 生成器

### 描述
生成可分享的 Link-in-Bio 静态页面（类 MediaKit 导出思路）：个人链接页 + 产品/链接列表 + 点击追踪（本地计数）。

### 实现原理
```
链接数据（用户配置：标题/URL/图标）
  ↓ 本地 HTML 模板渲染（Swift String 模板或轻量生成）
  ↓ 导出为自包含 HTML 文件（Documents/ 沙盒，类 MediaKit PDF 模式）
  ↓ ShareLink 分享 / 本地点击计数（UserDefaults）
```

### 注意点
1. **托管**：本地 App 无服务器 → 只生成静态 HTML 文件（用户自行托管）；不承诺在线服务。
2. **追踪**：点击计数仅本地（无法跨设备归因）——UI 需明确说明。
3. **合规**：纯前端无 API 依赖；链接内容合规自审。
4. **与 MediaKit 同模式**：复用 Documents 沙盒管理 + ShareLink 分享链路。

---

## 推荐实施顺序

1. **B. 内容→增长归因**（零 API、零风险、高差异化，与决策/内容档案互补）← 最先
2. **A. 评论触发私信**（ROI 最高，但需 manage_messages 权限 + Meta 审核周期）
3. **D. 九宫格视觉预览**（纯前端，快交付）
4. **C. Reels 深度分析**（需新增端点 + mock 扩展）
5. **E. Link-in-Bio**（静态导出，依赖用户自托管）

## 架构约束（所有新功能必须遵守）

- **本地优先**：数据不离开设备（除官方 Graph API 调用）
- **合规红线**：仅官方 OAuth + Graph API；禁止爬虫/浏览器模拟/明文密码/自动关注取关
- **确定性**：统计类功能纯函数 + 注入 RNG（测试可断言）
- **分层**：Service（业务/统计推断）→ Repository（数据）→ ViewModel（编排）→ View（呈现）
- **测试**：确定性函数至少 3 例/函数（边界/手算/恒等式）
