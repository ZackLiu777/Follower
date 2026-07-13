# Instagram API 数据需求映射

> **日期**：2026-07-09
> **API 类型**：Instagram Basic Display / Graph API

---

## 1. Instagram API 能力总览

| 能力 | 支持 | 端点 |
|------|:--:|------|
| 获取粉丝数量 | ✅ | `GET /me?fields=followers_count` |
| 获取自己发布的内容 | ✅ | `GET /me/media` |
| 获取内容的评论和互动 | ✅ | `GET /{media-id}/insights` |
| 管理消息和评论 | ✅ | `GET /{media-id}/comments` |
| 获取谁关注了你 | ❌ | 无端点 |
| 获取你关注了谁 | ❌ | 无端点 |
| 获取其他人的粉丝 | ❌ | 无端点 |
| 获取受众地域分布 | ⚠️ | 需 Business/ Creator 账号 |

---

## 2. 功能数据需求清单

### 2.1 Dashboard — 仪表盘

| 功能 | 需要的数据 | API | 方案 |
|------|----------|-----|------|
| Hero 粉丝总数 | `followers_count` | ✅ `GET /me` | 直接获取 |
| 粉丝 7 日变化量 | 7 天内 `followers_count` 历史 | ✅ `GET /me/insights?metric=follower_count&period=day` | insights |
| 互动率卡片 | `likes` + `comments` / `followers_count` | ✅ 自己内容的 insights | 计算 |
| Reach 触达 | 帖子触达人数 | ✅ `GET /me/insights?metric=reach` | insights |
| 帖子数量 | 媒体总数 | ✅ `GET /me?fields=media_count` | 直接获取 |
| 帖子列表 | 最近帖子 title / likes / comments / date | ✅ `GET /me/media?fields=id,caption,like_count,comments_count,timestamp` | 直接获取 |
| Mini 折线图 | 7 天 followers 数据点 | ✅ insights 历史 | 直接获取 |
| Post 详情视图 | 单帖 likes / comments / reach / saves | ✅ `GET /{media-id}/insights` | insights |

### 2.2 Trends — 趋势

| 功能 | 需要的数据 | API | 方案 |
|------|----------|-----|------|
| 粉丝增长趋势（日/周/月/年） | 各时间窗口 followers_count 序列 | ✅ `GET /me/insights` | insights |
| 互动趋势 | likes + comments 序列 | ✅ 自己帖子的互动数据 | 聚合计算 |
| 平均点赞/评论/分享/浏览 | 每帖 likes / comments / shares / views | ✅ `GET /me/media?fields=insights.metric(likes,comments,shares,impressions)` | 直接获取 |
| 趋势详情页 Hero 数值 | 当前值 + 变化量 | ✅ 历史数据计算 | 计算 |

### 2.3 Decisions — 增长决策

| 功能 | 需要的数据 | API | 方案 |
|------|----------|-----|------|
| Content Performance (Reel/Carousel/Photo) | 每种类型帖子的平均互动率 | ✅ `GET /me/media?fields=media_type,like_count,comments_count` | 分组计算 |
| Follower Health (活跃/不活跃比) | 粉丝互动频率分布 | ⚠️ 需 `GET /me/insights?metric=audience_activity` | Business 账号 |
| Timing Profile (最佳发帖时间) | 每帖发布时间 + 互动数 | ✅ 自己帖子的 `timestamp` + `like_count` | 分组统计 |
| Content Fatigue (疲劳检测) | 7 天内各类型帖子数量 | ✅ `GET /me/media` 过滤最近 7 天 | 计算 |
| 增长健康评分 | followers_count 30 日趋势 | ✅ insights | 计算 |
| 恢复需求评分 | 活跃粉丝比例 | ⚠️ 同 Follower Health | Business 账号 |

### 2.4 Premium — 高级功能

| 功能 | 需要的数据 | API | 方案 |
|------|----------|-----|------|
| Activity Analysis | 事件分布（按天/星期） | ✅ 自己帖子的 `timestamp` | 分组统计 |
| Retention & Churn | followers_count 历史序列 + 净增长 | ✅ insights | 计算 |
| Engagement Quality | likes×1 + comments×3 + shares×5 / views | ✅ 自己帖子的 insights | 加权计算 |
| Geo Distribution | 粉丝地域分布 | ❌ 需 `GET /me/insights?metric=audience_city` | **第三方** |
| Long-term Comparison | 两个时段 followers 均值对比 | ✅ insights 历史 | 计算 |
| Follower Prediction | 90 天历史 followers 数据 | ✅ insights → SMA/Linear Regression | 计算 |
| AI Analysis | Snapshot 序列 | ✅ 本地数据 | 规则引擎 |
| CSV/Excel Export | Snapshot / Metric 数据 | ✅ 本地已存储 | 直接导出 |

### 2.5 Settings — 设置

| 功能 | 需要的数据 | API | 方案 |
|------|----------|-----|------|
| 账号管理 | username / displayName / authState | ✅ OAuth 获取 | 直接获取 |
| 数据导出 | Snapshot / Metric / Event | ✅ 本地已存储 | 直接导出 |

---

## 3. 需要第三方方案的功能

| 功能 | Instagram 状态 | 第三方替代方案 |
|------|:---:|------|
| **Who Unfollowed You** | ❌ 无 API | SocialDog / Crowdfire API；或本地 diff（snapshot-based 推算） |
| **Geo Distribution** | ⚠️ Business 账号才有 | 若无 Business 账号 → Apify Instagram Scraper / Phantombuster |
| **Follower Health (active/inactive)** | ⚠️ Business 账号才有 | 同上；或从自己帖子互动中反向推算 |
| **受众画像 (年龄/性别)** | ❌ 无开放 API | Iconosquare / HypeAuditor API |

---

## 4. 总结

| 分类 | 数量 | 占比 |
|------|:--:|:--:|
| ✅ Instagram API 直接可获取 | 22 项 | 73% |
| ⚠️ 需 Business/Creator 账号 | 3 项 | 10% |
| ❌ 需第三方方案 | 4 项 | 13% |
| N/A (本地数据) | 2 项 | 7% |

**核心策略**：73% 的数据可由 Instagram Basic API 覆盖。`/me/media` + `/me/insights` 两个端点承载了绝大多数功能。4 项不支持的功能集中在"粉丝社交关系"层面（谁关注/取关、地域分布），需要接入 SocialDog 等第三方 API，或降级为本地推算。

---

**文档完。**
