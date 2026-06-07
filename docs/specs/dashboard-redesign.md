# Dashboard & Premium 重构设计

> 基于 App Store 竞品分析编写。  
> 目标：把 Dashboard 从"8 个平级卡片"转变为"有信息层次的 Instagram 分析首页"。

---

## 1. 当前状态的缺陷

### 1.1 信息层次

| 问题 | 现状 | 竞品做法 |
|------|------|---------|
| 没有 Hero 指标 | 8 个等大等权重的卡片 | 粉丝数作为主数字，大号字体 + 趋势方向 |
| 没有变化量 | 只显示绝对数（"1,234"） | 始终显示 delta（"+12 今天" / "-3% vs 上周"） |
| 没有方向指示 | 数字无颜色 | 涨绿跌红，箭头方向一目了然 |
| 没有内嵌图表 | 平面卡片 | Hero 卡片内部嵌 mini 折线图 |
| 没有内容级数据 | 不显示任何帖子信息 | 帖子列表是最重要的分析维度 |

### 1.2 Premium 定位

| 问题 | 现状 | 用户实际需要 |
|------|------|------------|
| 指标无意义 | Quality Score 0-100 用户不理解 | "谁取关了你" 用户立刻理解 |
| Mock 数据 | Geo Distribution 永远 🇺🇸 28.5% | 真实 Instagram API 才能提供地域 |
| 工程视角 | 服务名叫什么就展示什么 | 用户视角的付费价值主张 |

### 1.3 指标选择

Instagram 分析的用户关心：
1. **粉丝** — 涨了多少、跌了多少、谁取的关
2. **内容** — 哪个帖子表现最好、什么时间发最好
3. **互动** — 点赞/评论/分享 的变化趋势
4. **竞品** — 我 vs 同类账号的表现
5. **增长策略** — 我该怎么提升

当前的 8 个指标（Followers, Following, Media, Engagement Rate, Likes, Comments, Shares, Views）中，Following 和 Media 对分析价值很低，Likes/Comments/Shares 应该合并为一个 Engagement 维度。

---

## 2. 新 Dashboard 布局

```
┌─────────────────────────────────┐
│          ★ Followers            │  ← Hero 指标
│           12,345                │     大号数字
│       ↑ +234 (+1.9%)            │     变化量 + 百分比 + 颜色
│       vs last 7 days            │     对比周期
│  ┌───────────────────────────┐  │
│  │   ·  mini 7-day sparkline │  │     内嵌趋势（Swift Charts）
│  └───────────────────────────┘  │
└─────────────────────────────────┘

┌──────────┐ ┌──────────┐ ┌──────────┐
│Eng Rate  │ │  Reach   │ │  Posts   │    ← 次要指标，3 列
│ 4.2% ↑   │ │  89K →   │ │   52     │
└──────────┘ └──────────┘ └──────────┘

┌─────────────────────────────────┐
│ Recent Content                  │    ← 帖子列表（可滚动）
│ ┌─────────────────────────────┐ │
│ │ 📷  Jan 15  234♥  12💬     │ │      每行 = 一个帖子
│ │      Reach: 4.2K  Saves: 8 │ │      点击进入帖子详情
│ ├─────────────────────────────┤ │
│ │ 📹  Jan 14  567♥  34💬     │ │
│ │      Reach: 8.1K  Saves: 15│ │
│ ├─────────────────────────────┤ │
│ │ 📷  Jan 13  123♥   8💬     │ │
│ │      Reach: 2.3K  Saves: 3 │ │
│ └─────────────────────────────┘ │
│         [View All Posts →]      │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  🔒 Premium Insights            │    ← Premium 解锁后可见
│  ┌───────────────────────────┐  │
│  │ 👤 Who Unfollowed You    │  │      付费功能
│  │ 🕐 Best Time to Post     │  │
│  │ 📊 Content Strategy      │  │
│  │ 🔍 Profile Audit        │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

### 2.1 Hero 指标

**唯一主数字**：粉丝数。这是用户每次打开 App 最关心的一件事。

```swift
struct HeroMetricCard: View {
    let followers: Int
    let delta: Int           // +234
    let deltaPercent: Double // +1.9%
    let period: String       // "vs last 7 days"
    let sparklineData: [Double] // 内嵌趋势数据
}
```

**数据来源**：Snapshot.latest + 近 7 天 Snapshot 计算 delta。

### 2.2 次要指标栏

3 个指标，一行：

| 指标 | 内容 | 数据来源 |
|------|------|---------|
| Engagement Rate | 4.2% ↑0.3% | latest Snapshot |
| Reach | 89K → | latest Snapshot.totalViews |
| Posts | 52 +3 this week | latest Snapshot.mediaCount + 变化 |

每个小卡片显示数值 + 变化方向箭头 + 颜色。

### 2.3 帖子列表

**这是最重要的新增功能**。竞品 100% 都有内容列表。

```swift
struct PostRow: Identifiable {
    let id: String
    let type: PostType        // .image / .video / .carousel
    let date: Date
    let thumbnailColor: Color // 占位色块
    let likes: Int
    let comments: Int
    let reach: Int
    let saves: Int
}
```

**数据来源**：全部 Mock（真实帖子数据需要 Instagram Graph API `/media` 端点）。Mock 策略：随机生成 20-30 条帖子，点赞范围 50-5000，评论范围 5-200。

**点击行为**：每行点击进入 `PostDetailView`，展示大图占位 + 互动详情 + 评论区 Mock。

### 2.4 Premium 区域

替代当前的 4 个无意义卡片。每个 Premium 功能是**用户能理解的价值主张**：

| Premium 功能 | 用户看到的 | 实现 |
|-------------|-----------|------|
| 谁取关了你 | "3 people unfollowed you this week" → 点击看列表 | Mock 用户名 + 头像 + 取关时间 |
| 最佳发帖时间 | "Your best posting time: Wed 7PM" → 点击看热力图 | Mock 按星期+小时的互动热力图 |
| 内容策略建议 | "Carousel posts get 2.3x more engagement than single images" | 基于 Mock 数据的规则引擎输出 |
| 账号健康检查 | "Your profile is 85% complete. Add a bio link to improve." | 规则引擎检查 bio/头像/发帖频率 |
| 粉丝真假检测 | "12% of your followers may be bots" | Mock 百分比 |
| CSV 导出增强 | "Export all data with engagement per post" | ExportService 已有基础 |
| Excel 导出 | "Export for Excel with charts" | ExportService.exportAsExcel() |
| 趋势预测 | "Predicted followers next month: 13,200" | PredictionService 已有 |

---

## 3. 新文件结构

```
Follower/Features/Dashboard/
├── DashboardView.swift           # 重构：Hero + 次要指标 + 帖子列表 + Premium
├── DashboardViewModel.swift      # 重构：加载 Post 列表 + Premium insights
├── HeroMetricCard.swift          # 新：大号粉丝数卡片
├── SecondaryMetricRow.swift      # 新：Eng Rate / Reach / Posts 一行三个
├── PostRowView.swift             # 新：单条帖子行

Follower/Features/Posts/          # 新 Feature
├── PostListView.swift            # 帖子完整列表
├── PostDetailView.swift          # 帖子详情页
├── PostDetailViewModel.swift     # 帖子详情 VM

Follower/Services/Mock/
├── MockPostGenerator.swift       # 新：生成 Mock 帖子数据
├── MockFollowerListGenerator.swift # 新：生成 Mock 粉丝/取关列表
```

---

## 4. 实现拆分

### Step 1：Hero 卡片重构（不依赖 Premium）
- 替换 8 卡片为 Hero + 3 次要指标
- 添加变化量计算（`SnapshotRepository.fetch` 7 天数据）
- 内嵌 mini 折线图

### Step 2：帖子列表（Mock 数据）
- 创建 `MockPostGenerator`
- Dashboard 底部显示最近 5 条帖子
- 每条可点击 → PostDetailView

### Step 3：Premium 区域重设计
- 删除旧的 Premium 卡片
- 显示用户可理解的 Premium 功能列表
- 每个功能点开有实际内容（Mock）
- 复用已有的 PremiumGate 门控

### Step 4：详情页
- 每个 Hero/次要指标可点击 → 各自的 DetailView
- 详情页展示更细粒度的图表 + 列表
- Premium 门控：基础趋势免费，细分数据（谁取关）Premium

---

## 5. 不变的部分

- Model / Repository / Service 层**零修改**（新功能全部基于已有数据 + Mock）
- 数据库 Schema 不变
- 现有 Trends / Settings / Account 页面不变
- 所有已有测试继续通过

---

## 6. 数据源汇总

| 数据 | 来源 | 状态 |
|------|------|------|
| 粉丝数 + 趋势 | Snapshot 表 | ✅ 已有 |
| 粉丝变化量 | Snapshot 计算 | ✅ 可计算 |
| 互动率 | Snapshot.engagementRate | ✅ 已有 |
| Reach | Snapshot.totalViews | ✅ 已有 |
| 帖子数 | Snapshot.mediaCount | ✅ 已有 |
| 帖子列表（标题/赞/评/触达） | MockPostGenerator | 🆕 Mock |
| 取关列表（头像/用户名/时间） | MockFollowerListGenerator | 🆕 Mock |
| 最佳发帖时间 | Mock 热力图数据 | 🆕 Mock |
| 内容策略建议 | 规则引擎（基于 Mock 数据） | 🆕 规则引擎 |
| 粉丝真假检测 | Mock 百分比 | 🆕 Mock |

---

*下一步：按 Step 1 → 2 → 3 → 4 顺序实现，每个 Step 单独 commit。*
