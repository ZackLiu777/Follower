# 仪表盘重构 + 设置页迁移记录

> **日期**：2026-08-01
> **状态**：已完成
> **分支**：omega

---

## 1. 仪表盘重构

### 1.1 顶栏账号图标

| 变更 | 说明 |
|------|------|
| 位置 | 从左上角（左侧头像+用户名）→ **右上角**，且上移（`padding(.top, 2)`） |
| 吸顶 | AccountBar 移出 ScrollView（外层 VStack 固定）→ **向下滚动始终显示** |
| 文字 | 删除 `@username` 和「Instagram 账户」文字 |
| 样式 | **Liquid Glass**：`.ultraThinMaterial` + `theme.cardSurface` 叠层 + `theme.divider` 描边 + 阴影 |
| 交互 | 点击头像 → 弹出**非全屏设置弹窗**（直接呈现设置页内容，无中间层） |
| 多账户 | >1 个账号时头像左侧显示 `chevron.up.down` 快速切换菜单 |

### 1.5 账号个人资料弹窗（AccountProfileSheet）

点击头像弹出的**非全屏 sheet**（`presentationDetents([.large])`，圆角 24），参考 Health 个人资料页结构：

```
✕（右上角，透明无填充）
👤 头像 + @username

┌────────────────────────────┐
│ 活动状态                     │
│ 🏃 活动状态      ›  Authorized │
│ ──────────────────────────  │
│ 个性化                       │
│ 👤 账号（多账号切换菜单）  ›    │
│ ⚙️ 设置              ›       │
│ 📚 集成（添加账号）     ›       │
└────────────────────────────┘  ← 一张 Liquid Glass 卡片
```

- 「设置 ›」→ **同一弹窗内切换**到完整设置页（`SettingsView`，Form 多 Section：Trial/账号/语言/主题/导出/存储/隐私/Premium），左上角返回按钮回个人资料页，**无导航嵌套 push**
- **无拖拽小横条**（`.presentationDragIndicator(.hidden)`）
- ✕ 关闭按钮（`profile_close_button`）——纯 `xmark`，**无填充、无背景色，完全透明**
- 设置返回按钮 `profile_back_button`、账号菜单 `profile_accounts_menu`、设置入口 `profile_settings_link`

### 1.2 删除项

- **粉丝趋势折线图卡片**（TrendChart + NavigationLink 整块删除）
- **覆盖人数（reach）指标**（原三列指标中的中间列）

### 1.3 指标卡片重构（KeyMetricsSection）

由「3 列横排」改为「2 张卡片**竖向堆叠**」，每张卡片含主指标 + 3 个附加指标，背景统一 **Liquid Glass**（`dashboardCard()`）：

**互动率卡片**（heart.fill）
- 主指标：互动率 `%.1f%%` + 周变化 delta
- 附加：总赞 / 总评论 / 总分享

**帖子数卡片**（doc.text.fill）
- 主指标：帖子数 + 周变化 delta
- 附加：总曝光（views）/ 平均赞每帖 / 平均评论每帖

### 1.4 布局顺序

```
顶栏（右上角头像）
↓
最近内容（上移至原折线图位置）
↓
指标卡片（互动率 + 帖子数，竖向）
↓
Premium Insights
```

---

## 2. 设置页迁移（删除 Settings Tab）

### 2.1 入口变更

- **删除底部 Settings Tab**（TabView 从 4 个 → 3 个：仪表盘 / 趋势 / 决策）
- 设置页（`SettingsView`）改为**账号详细页**，从仪表盘右上角头像 push 进入
- `SettingsViewModel` 创建位置从 `ContentView` 移到 `DashboardView`（由 ContentViewInner 创建后传入）

### 2.2 SettingsView 内部调整

| 变更 | 说明 |
|------|------|
| 删除内部 `NavigationStack` | 改为被 push 的目标页（保留 ZStack + Form + sheet） |
| 账号列表行可点击 | 点击行 = 切换当前选中账号（勾选标记 `checkmark.circle.fill`），替代原顶部切换菜单 |
| 导航栏 | `.navigationTitle` 保留，返回按钮由外层 NavigationStack 提供 |

### 2.3 新增本地化

| Key | en | ja | zh-Hans | zh-Hant |
|-----|----|----|---------|---------|
| `dashboard.avgLikes` | Avg Likes/Post | 平均いいね/投稿 | 平均赞/帖 | 平均讚/貼文 |
| `dashboard.avgComments` | Avg Comments/Post | 平均コメント/投稿 | 平均评论/帖 | 平均留言/貼文 |

---

## 3. 测试更新

| 文件 | 变更 |
|------|------|
| `SettingsUITests.swift` | 原「Settings Tab 存在」改为：Tab 数 = 3 + 头像 → 弹窗关闭按钮/设置入口 |
| `AccountUITests.swift` | 原「导航到 Settings Tab」改为：点击 `account_avatar_button` → 弹窗 → 设置页 |
| `PremiumUITests.swift` | 2 个经 Settings Tab 进入的测试改为：头像 → 弹窗 → 设置页 |

accessibilityIdentifier：`account_avatar_button`（头像）、`profile_close_button`（弹窗关闭）、`profile_settings_link`（设置入口）、`profile_back_button`（返回）、`profile_accounts_menu`（账号切换）。

---

## 4. 涉及文件

- `Follower/Features/Shared/AccountBar.swift` — 顶栏重构（吸顶 + 头像弹出个人资料弹窗）
- `Follower/Features/Shared/DashboardCard.swift` — **新增**：`dashboardCard()` 提取为共享 internal 修饰符
- `Follower/Features/Account/AccountProfileSheet.swift` — **新增**：个人资料弹窗（活动状态 + 个性化入口 + 设置切换）
- `Follower/Features/Dashboard/DashboardView.swift` — 布局（AccountBar 移出 ScrollView）+ KeyMetricsSection 重构
- `Follower/Features/Settings/SettingsView.swift` — 恢复 Form 多 Section（设置完整内容页）
- `Follower/ContentView.swift` — 删 Settings Tab
- `Follower/Core/Localization/L10n.swift` + `Localizable.xcstrings` — 新增 4 个 key（avgLikes/avgComments/activityStatus/personalization）
- `FollowerUITests/*` — 3 个测试文件入口更新

> 迭代记录：曾尝试「头像 → 直接弹设置页」和「设置全部塞进一张卡片」两种方案，最终采用 Health 风格个人资料弹窗（入口行 + 弹窗内切换设置页）。
