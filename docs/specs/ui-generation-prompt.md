# Follower — UI Generation Prompt

> 本 Prompt 用于指导 AI 代码生成工具（如 Claude、v0、Bolt 等）生成 Follower App 的完整 SwiftUI 界面。
> 目标平台：iOS 26+ · 框架：SwiftUI · 架构：MVVM
> 语言支持：en / zh-Hans / zh-Hant / ja

---

## App Identity

**App Name:** Follower
**Tagline:** 本地优先的 Instagram 数据追踪与分析工具
**One-liner:** Track your Instagram growth, privately. All data stays on your device.
**Tone:** 专业、克制、可信赖。不是社交产品，是分析工具。
**Personality:** 像一个懂数据的安静助手，不打扰、不炫耀、不制造焦虑。

---

## 1. Color System

### 1.1 Apple Native Theme（浅色 / 深色自适应）

```
Background Primary:    #FFFFFF (Light) / #000000 (Dark)
Background Secondary:  #F2F2F7 (Light) / #1C1C1E (Dark)
Background Tertiary:   #E5E5EA (Light) / #2C2C2E (Dark)
Card Background:       #FFFFFF (Light) / #1C1C1E (Dark)
Text Primary:          #000000 (Light) / #FFFFFF (Dark)
Text Secondary:        #3C3C43 60% (Light) / #EBEBF5 60% (Dark)
Text Tertiary:         #3C3C43 30% (Light) / #EBEBF5 30% (Dark)
Separator:             #3C3C43 20% (Light) / #545458 60% (Dark)
Accent Blue:           #007AFF
Accent Green:          #34C759
Accent Red:            #FF3B30
Accent Orange:         #FF9500
Accent Purple:         #AF52DE
```

### 1.2 Instagram Theme（品牌风格）

```
Gradient Primary:      #F58529 → #DD2A7B → #8134AF → #515BD4
                       (Instagram 经典四色渐变，45° 对角线)
Background Primary:    #FAFAFA (Light) / #0A0A0A (Dark)
Background Secondary:  #F0F0F0 (Light) / #1A1A1A (Dark)
Card Background:       #FFFFFF 95% (Light, frosted) / #1A1A1A 85% (Dark, frosted)
Text Primary:          #262626 (Light) / #F5F5F5 (Dark)
Text Secondary:        #8E8E8E (Light) / #A8A8A8 (Dark)
Separator:             #DBDBDB (Light) / #363636 (Dark)
Accent:                从主渐变中提取 #DD2A7B (强调色)
Success:               #78DE45
Warning:               #FFDC5C
```

### 1.3 Midnight Dark Theme

```
Background Primary:    #0D0D0F
Background Secondary:  #161618
Background Tertiary:   #1E1E21
Card Background:       #161618 90% (frosted dark)
Text Primary:          #F0F0F2
Text Secondary:        #98989E
Text Tertiary:         #636369
Separator:             #2A2A2E
Accent:                #0A84FF (冷调蓝)
```

### 1.4 Instagram Dark Theme

```
Background Primary:    #0A0A0A
Background Secondary:  #121212
Background Tertiary:   #1E1E1E
Card Background:       #121212 85% (frosted black)
Text Primary:          #F5F5F5
Text Secondary:        #A8A8A8
Separator:             #262626
Accent:                同 Instagram 渐变体系
```

---

## 2. Typography

```
使用系统字体 San Francisco，通过 SwiftUI Text Style 映射：

Large Title:   .largeTitle    — 页面主标题（Dashboard "你好，用户"）
Title 1:       .title         — 区域标题
Title 2:       .title2        — Section 标题（"统计卡片"）
Title 3:       .title3        — 次级标题
Headline:      .headline     — 卡片内指标标签（"粉丝数"）
Body:          .body          — 正文
Callout:       .callout       — 数值展示（"12,345"）
Subheadline:   .subheadline   — 辅助说明
Footnote:      .footnote      — 时间戳、数据来源
Caption 1/2:   .caption       — 最小说明文本

字体权重规则：
- 数据数值：.system(.title2, weight: .semibold, design: .rounded)
- 指标标签：.system(.subheadline, weight: .medium)
- 按钮文字：.system(.body, weight: .semibold)
- 空状态提示：.system(.body, weight: .regular)
```

---

## 3. Spacing & Layout

```
Page Margins:          horizontal 16pt, top 12pt, bottom 24pt (含安全区)
Card Padding:          16pt all sides
Card Spacing:          12pt vertical
Section Spacing:       24pt vertical
Grid Gutter:           12pt (Dashboard 2列网格)
Icon Size (small):     16pt
Icon Size (medium):    24pt
Icon Size (large):     32pt
Tab Bar Icon:          24pt (SF Symbols, .systemGray2 未选中 / .accentColor 选中)
Corner Radius (card):  16pt
Corner Radius (button): 12pt
Corner Radius (sheet): 20pt (top)
Shadow (card):         y=2 blur=8 opacity=0.08
Shadow (elevated):     y=4 blur=16 opacity=0.12
```

---

## 4. Liquid Glass 效果规范

```
仅在性能充裕时启用（可通过 .liquidGlassDisabled() modifier 降级）。

Card 效果：
  .background(.ultraThinMaterial)
  .clipShape(RoundedRectangle(cornerRadius: 16))
  .shadow(color: .black.opacity(0.08), radius: 8, y: 2)

禁用降级：
  .background(theme.cardBackground)
  .clipShape(RoundedRectangle(cornerRadius: 16))
  .shadow(color: .black.opacity(0.04), radius: 4, y: 1)

Liquid Glass 不得改变：
  - 布局结构
  - 数据流
  - 交互行为
```

---

## 5. Iconography

```
Tab Bar (SF Symbols)：
  - Dashboard:  "rectangle.grid.2x2.fill"
  - Trends:     "chart.line.uptrend.xyaxis"
  - Settings:   "person.fill"（我的）

Dashboard 卡片图标（SF Symbols, 16pt, 主题 accent）：
  - Followers:     "person.2.fill"
  - Following:     "person.fill.checkmark"
  - Media:         "photo.stack.fill"
  - Engagement:    "heart.text.square.fill"
  - Likes:         "heart.fill"
  - Comments:      "text.bubble.fill"
  - Shares:        "arrowshape.turn.up.forward.fill"
  - Profile Views: "eye.fill"

状态图标：
  - Premium Lock:  "lock.fill"
  - Premium Unlock: "lock.open.fill"
  - Export:        "square.and.arrow.up"
  - Error:         "exclamationmark.triangle.fill"
  - Empty:         "tray"
  - Loading:       "arrow.triangle.2.circlepath"
  - Check:         "checkmark.circle.fill"
  - Close:         "xmark.circle.fill"
  - Warning:       "exclamationmark.circle.fill"
  - Language:      "globe"
  - Theme:         "paintpalette.fill"
  - Privacy:       "hand.raised.fill"
  - Storage:       "externaldrive.fill"
  - Delete:        "trash.fill"
  - Refresh:       "arrow.clockwise"
```

---

## 6. Screen Specifications

### 6.1 Launch / Splash Screen

```
全屏 Instagram 品牌渐变背景（#F58529 → #DD2A7B → #8134AF → #515BD4, 45°, 0.6 不透明度）

居中区域：
  - App 图标（Assets.xcassets 中的 AppIcon，圆角方形，72pt）
  - App 名称 "Follower"（.largeTitle, .bold, white）
  - Tagline "本地优先 · 数据私有"（.subheadline, white 0.7）

入场动画：
  - 图标从 scaleEffect(0.8) + opacity(0) → scaleEffect(1.0) + opacity(1)，0.6s easeOut
  - 文字 stagger 出现，每个 letter 延迟 0.05s
  - 整体动画时长 2.0s，完成后自动导航到 ContentView

深色模式变体：
  - 渐变叠加 30% 黑色遮罩层
  - 其余一致
```

### 6.2 Dashboard 页

```
═══════════════════════════════════════
  [NavigationStack]
  ┌─────────────────────────────────┐
  │ Follower                    [⋯] │  ← nav title inline, trailing: 导出菜单
  ├─────────────────────────────────┤
  │ [Account Picker]                │  ← 下拉选择账号，当前账号名+平台图标
  │   @username · Instagram   ▼     │
  ├─────────────────────────────────┤
  │ ┌──────────┐ ┌──────────┐      │
  │ │ 👥 粉丝   │ │ ✅ 关注   │      │  ← 2x4 网格卡片
  │ │ 12,345   │ │   890    │      │     StatCard 组件
  │ │ +2.3% ↑  │ │  持平     │      │     每卡：图标 + 标签 + 数值 + 变化率
  │ └──────────┘ └──────────┘      │
  │ ┌──────────┐ ┌──────────┐      │
  │ │ 📷 帖子   │ │ ❤️ 互动   │      │
  │ │   456    │ │  3.2%    │      │
  │ │ +12 ↑    │ │ -0.5% ↓  │      │
  │ └──────────┘ └──────────┘      │
  │ ┌──────────┐ ┌──────────┐      │
  │ │ 👍 点赞   │ │ 💬 评论   │      │
  │ │  8,900   │ │  1,234   │      │
  │ │ +5.1% ↑  │ │ +1.2% ↑  │      │
  │ └──────────┘ └──────────┘      │
  │ ┌──────────┐ ┌──────────┐      │
  │ │ 🔄 分享   │ │ 👁️ 主页访问│      │
  │ │   234    │ │  5,678   │      │
  │ │ -1.1% ↓  │ │ +8.3% ↑  │      │
  │ └──────────┘ └──────────┘      │
  │                                 │
  │ ─── Premium 解锁后 ───          │
  │ ┌────────────────────────────┐  │
  │ │ ⭐ 互动质量评分         85  │  │  ← Premium 卡片，未解锁时显示 🔒
  │ │ 较上周 +3 ↑                │  │     解锁后：实际数据
  │ └────────────────────────────┘  │     未解锁：毛玻璃遮罩 + Lock 图标
  │ ┌────────────────────────────┐  │
  │ │ 📊 活跃度            87%   │  │
  │ │ 本月活跃天数 26/30         │  │
  │ └────────────────────────────┘  │
  │ ┌────────────────────────────┐  │
  │ │ 🌍 地域分布                │  │
  │ │ 美国 45% · 日本 22% · ...  │  │
  │ └────────────────────────────┘  │
  └─────────────────────────────────┘

交互：
  - 下拉刷新：触发 SyncEngine 同步，ProgressView 在顶部
  - 点击卡片（基础统计）：无操作（只读）
  - 点击 Premium 卡片（未解锁）：弹出 PremiumGate sheet
  - 长按任意卡片：数值复制到剪贴板 + 轻 haptic
  - 导航栏右侧 "⋯"：导出菜单（JSON / CSV / Excel[Premium]）

空状态（无账号时）：
  ┌─────────────────────────────────┐
  │        [tray icon, 48pt]       │
  │    还没有连接任何账号            │
  │  请前往「我的」→ 连接账号开始追踪  │
  │       [去连接账号] 按钮          │
  └─────────────────────────────────┘

加载状态：
  - 首次加载：居中 ProgressView + "正在加载数据..."
  - 刷新中：顶部 ProgressView（pull-to-refresh 区域）
  - 卡片区域显示 8 个骨架屏（shimmer placeholder）

错误状态：
  - ErrorBanner 从顶部滑入（红色背景，白色文字，3s 自动消失）
  - 显示具体错误信息 + "重试" 按钮
```

### 6.3 Trends 趋势页

```
═══════════════════════════════════════
  [NavigationStack]
  ┌─────────────────────────────────┐
  │ Trends                          │  ← nav title inline
  ├─────────────────────────────────┤
  │ [日] [周] [月]                  │  ← Segmented Picker (.pickerStyle(.segmented))
  │                      [对比 ▾]    │  ← Premium: 对比模式按钮
  ├─────────────────────────────────┤
  │ ┌─────────────────────────────┐ │
  │ │      粉丝增长趋势           │ │  ← Section title + 时间范围
  │ │                             │ │
  │ │  ██                         │ │  ← 竖条柱状图 (Bar Chart)
  │ │  ██ ██                      │ │     x轴：日期
  │ │  ██ ██ ██                   │ │     y轴：数值
  │ │  ██ ██ ██ ██ __            │ │     柱子颜色：Instagram 渐变
  │ │  ██ ██ ██ ██ ██ ██ ██      │ │     默认 7 条（日）/ 4 条（周）/ 12 条（月）
  │ │  03 04 05 06 07 08 09      │ │
  │ └─────────────────────────────┘ │
  │                                 │
  │ ┌─────────────────────────────┐ │
  │ │      互动率趋势             │ │  ← 可滑动查看更多指标图表
  │ │  ██                         │ │
  │ │  ██ ██                      │ │
  │ │  ██ ██ ██                   │ │
  │ │  ...                        │ │
  │ └─────────────────────────────┘ │
  │                                 │
  │ ┌─────────────────────────────┐ │
  │ │      帖子数趋势             │ │
  │ │  ██ ██                      │ │
  │ │  ...                        │ │
  │ └─────────────────────────────┘ │
  │                                 │
  │ 增长摘要区域：                   │
  │ ┌─────────────────────────────┐ │
  │ │ 📈 本周增长                  │ │
  │ │ 粉丝 +234 · 互动率 +0.3%     │ │
  │ │ 帖子 +12 · 点赞 +890        │ │
  │ └─────────────────────────────┘ │
  └─────────────────────────────────┘

Trends 页布局规则：
  - 整个趋势区域使用 ScrollView(.vertical)
  - 柱子图高度固定为 200pt
  - 柱子宽度自适应（日：48pt, 周：64pt, 月：24pt）
  - 柱子间距 4pt
  - 柱子圆角 top 8pt, bottom 2pt
  - 柱子颜色：Instagram 渐变从顶部到底部 (F58529→DD2A7B)
  - 选择日/周/月时，柱子数量和日期格式同步切换
  - Premium 对比模式：同一图表内显示两组柱子（当前周期 vs 对比周期），
    当前周期实心渐变，对比周期半透明灰色

空状态（无数据）：
  ┌─────────────────────────────────┐
  │        [chart icon, 48pt]      │
  │     还没有足够的数据生成趋势      │
  │  同步账号数据后即可查看历史趋势    │
  └─────────────────────────────────┘
```

### 6.4 Settings（我的） 页

```
═══════════════════════════════════════
  [NavigationStack]
  ┌─────────────────────────────────┐
  │ 我的                            │  ← nav title inline
  ├─────────────────────────────────┤
  │                                 │
  │ ┌ Trial Status ──────────────┐ │
  │ │ 🕐 试用剩余 42 分钟          │ │  ← 试用中：倒计时 + 进度条
  │ │ [===========     ] 70%     │ │     试用结束：显示"基础版" + "升级 Premium"
  │ └────────────────────────────┘ │
  │                                 │
  │ ┌ Account ───────────────────┐ │
  │ │ 连接账号                     │ │
  │ │ @zane_liao · Instagram   > │ │  ← 已连接时显示账号信息 + 展开箭头
  │ │                             │ │     未连接时显示 "+ 添加账号"
  │ │ @photolab · Instagram    > │ │
  │ │ [+ 添加账号]                │ │
  │ └────────────────────────────┘ │
  │                                 │
  │ ┌ Premium ───────────────────┐ │
  │ │ CSV 增强导出            ✓  │ │  ← 绿色对号 = 已解锁
  │ │ Excel 导出              ✓  │ │
  │ │ 长期趋势对比            ✓  │ │
  │ │ 互动质量评分            ✓  │ │
  │ │ 活跃度分析              ✓  │ │
  │ │ 留存流失分析            ✓  │ │
  │ │ 趋势预测                ✓  │ │
  │ │ 地域分布                ✓  │ │
  │ │ 本地 AI 分析            ✓  │ │
  │ │ 强数据加密              ✓  │ │
  │ │多设备同步               ✓  │ │
  │ │                             │ │
  │ │ [🔓 一键解锁全部高级功能]    │ │  ← 开发模式按钮，黄色底色
  │ └────────────────────────────┘ │
  │                                 │
  │ ┌ Preferences ───────────────┐ │
  │ │ 🌐 语言         简体中文 > │ │  ← Picker: en/zh-Hans/zh-Hant/ja
  │ │ 🎨 主题     Apple Native > │ │  ← Picker: 4 个主题
  │ │ ☀️ 外观          跟随系统 > │ │  ← Picker: System/Light/Dark
  │ └────────────────────────────┘ │
  │                                 │
  │ ┌ Data ──────────────────────┐ │
  │ │ 📤 导出数据               > │ │  ← 跳转导出选项
  │ │ 📊 存储说明               > │ │  ← 展示 SQLite 路径和大小
  │ │ 🔒 隐私政策               > │ │  ← 内置隐私说明页
  │ └────────────────────────────┘ │
  │                                 │
  │ ┌ Danger Zone ───────────────┐ │
  │ │ 🗑️ 删除所有数据             │ │  ← 红色按钮，需要二次确认
  │ └────────────────────────────┘ │
  │                                 │
  │ App 版本: v0.03-gamma           │  ← footnote, centered, secondary
  └─────────────────────────────────┘
```

### 6.5 Account 账号管理页

```
═══════════════════════════════════════
  [NavigationStack] ← dismiss button
  ┌─────────────────────────────────┐
  │ 连接账号              [完成]    │  ← nav title + toolbar button
  ├─────────────────────────────────┤
  │                                 │
  │ 平台（只读，固定 Instagram）：   │
  │ ┌─────────────────────────────┐ │
  │ │ 📷 Instagram               │ │  ← 唯一选项（Gamma 移除 TikTok UI）
  │ └─────────────────────────────┘ │
  │                                 │
  │ 用户名：                        │
  │ ┌─────────────────────────────┐ │
  │ │ @username                   │ │  ← TextField, 带 placeholder
  │ └─────────────────────────────┘ │
  │                                 │
  │ 展示名（可选）：                 │
  │ ┌─────────────────────────────┐ │
  │ │ Zane Liao                   │ │
  │ └─────────────────────────────┘ │
  │                                 │
  │ [保存账号] 按钮                  │  ← 主操作，蓝色全宽圆角按钮
  │                                 │     创建成功后自动 dismiss 回 Settings
  │                                 │
  │ ─── 已有账号列表 ───             │
  │ ┌─────────────────────────────┐ │
  │ │ @zane_liao          ✓ 已连接│ │  ← Swipe to delete
  │ │ Instagram · 创建于 2026-06  │ │     长按显示 "撤销"（undo insert）
  │ └─────────────────────────────┘ │
  └─────────────────────────────────┘
```

---

## 7. Shared Components

### 7.1 StatCard

```
┌──────────────────────────┐
│ [icon]         [+2.3% ↑] │  ← 18pt SF Symbol, 右上变化率 badge
│                          │
│ 粉丝数                    │  ← subheadline, secondary text
│ 12,345                   │  ← title2, semibold, rounded design
└──────────────────────────┘

Size: (screenWidth - 48) / 2 宽 × 100pt 高
Background: theme.cardBackground
Corner: 16pt, shadow y=2 blur=8 opacity=0.08
变化率颜色：
  - 增长（>0）：green (#34C759)
  - 下降（<0）：red (#FF3B30)
  - 持平（=0）：secondary text
变化率箭头：
  - 增长：↑ (arrow.up)
  - 下降：↓ (arrow.down)
  - 持平：→ (arrow.right)
```

### 7.2 TrendBarChart

```
竖条柱状图组件（Gamma-2 新设计）：

┌──────────────────────────────┐
│ 粉丝增长趋势                  │  ← section header (headline)
│                              │
│  ██                          │  ← bar: rounded top(8pt) bottom(2pt)
│  ██ ██                       │      渐变填充 (F58529 top → DD2A7B bottom)
│  ██ ██ ██                    │      宽度自适应 (日48/周64/月24pt)
│  ██ ██ ██ ██ __             │      间距 4pt
│  ██ ██ ██ ██ ██ ██ ██      │
│  03  04  05  06  07  08  09  │  ← x轴标签 (footnote, secondary)
│  6月                          │  ← 月份标尺
│                单位：粉丝数    │  ← y轴说明 (caption, tertiary)
└──────────────────────────────┘

Chart 属性：
  - 使用 Swift Charts 框架 (Chart { BarMark } )
  - 总高度 200pt
  - x轴：日期（日/周/月 自动切换格式）
  - y轴：自适应 scale，顶部留 10% padding
  - 柱子默认填充 Instagram 主渐变
  - 可通过 .chartForegroundStyleScale 切换主题色
  - 支持 touch 显示数值 tooltip
```

### 7.3 PremiumGate Modifier

```
未解锁状态：
  Card 上方叠加 Layer：
    - 半透明毛玻璃遮罩（.ultraThinMaterial, opacity 0.7）
    - 居中 🔒 图标（32pt, SF Symbol "lock.fill"）
    - 下方文字 "Premium 功能"（caption, secondary）
    - 点击触发 PremiumGateSheet

解锁状态：
  - 正常显示内容，无遮罩

PremiumGateSheet（升级提示页）：
  ┌─────────────────────────────────┐
  │         [dismiss]               │
  │                                 │
  │       ⭐ Premium                │
  │                                 │
  │  解锁全部高级分析功能：           │
  │  • Excel 导出                   │
  │  • 长期趋势对比                  │
  │  • 互动质量评分                  │
  │  • 活跃度分析 + 留存分析         │
  │  • 趋势预测 + 地域分布           │
  │  • 本地 AI 分析                 │
  │                                 │
  │     [🔓 一键解锁全部功能]        │  ← 开发模式按钮
  │                                 │
  │  基础版功能永久免费使用           │  ← footnote, tertiary
  └─────────────────────────────────┘
```

### 7.4 ErrorBanner

```
从顶部安全区滑入，覆盖在 NavigationStack 上方：

┌─────────────────────────────────┐
│ ⚠️ 同步失败：网络连接超时  [重试] │  ← 红色背景 #FF3B30 15% + 红色文字
└─────────────────────────────────┘
  - 高度 48pt（含 safe area）
  - 进入动画：move(edge: .top) + opacity, 0.3s easeOut
  - 退出动画：move(edge: .top) + opacity, 0.3s easeIn
  - 自动消失时间：3s（如点击"重试"则立即消失）
  - 点击"重试"触发ViewModel.retry()
```

### 7.5 EmptyState

```
居中，距顶部 30% 屏幕高度：

  ┌─────────────────────────┐
  │                         │
  │     [SF Symbol, 48pt]   │  ← 颜色 tertiary
  │                         │
  │     还没有任何数据        │  ← body, secondary
  │   前往"我的"连接账号开始   │  ← subheadline, tertiary
  │                         │
  │     [去连接账号]         │  ← 可选 action button
  └─────────────────────────┘
```

### 7.6 Skeleton Loading

```
首次加载时，卡片区域显示：
  - 8 个圆角矩形占位（尺寸同 StatCard）
  - 使用 shimmer 动画（线性渐变从左到右移动，opacity 0.3 → 0.6 → 0.3）
  - 动画：1.5s 循环，.easeInOut
  - 颜色：theme.cardBackground → theme.separator → theme.cardBackground
```

---

## 8. Navigation & Architecture

### 8.1 TabView 结构

```
TabView (4 tabs)：
  Tab 0: Dashboard  (icon: rectangle.grid.2x2.fill)
  Tab 1: Trends     (icon: chart.line.uptrend.xyaxis)
  Tab 2: Settings   (icon: person.fill, title: "我的")

每个 Tab 包裹在独立的 NavigationStack 中
Tab 切换保持各自 NavigationStack 状态
```

### 8.2 Navigation Patterns

```
NavigationStack（所有主要页面）
  ↓ push
  ├── AccountView（from Settings "连接账号"）
  ├── ExportOptionsView（from Dashboard "⋯" 菜单 / Settings "导出数据"）
  ├── PrivacyPolicyView（from Settings "隐私政策"）
  └── StorageInfoView（from Settings "存储说明"）

Sheet（模态）：
  ├── PremiumGateSheet（from 任何 Premium 锁定卡片或按钮）
  └── DeleteConfirmationSheet（from Settings "删除所有数据"）

Alert（系统弹窗）：
  └── DeleteAccountAlert（from Account 页 swipe-to-delete）
```

---

## 9. State Handling Matrix

### 每个页面必须覆盖以下 4 种状态：

| 页面 | Loading | Empty | Error | Loaded |
|------|---------|-------|-------|--------|
| Dashboard | 8 骨架屏 + shimmer | "还没有连接账号" | ErrorBanner + 上次缓存数据 | 8 格卡片网格 + Premium 卡片 |
| Trends | 图表骨架屏 + shimmer | "还没有足够的数据" | ErrorBanner + 上次缓存图表 | 柱状图 + 增长摘要 |
| Settings | 表单 section 占位 | N/A（始终有内容） | ErrorBanner（导出失败等） | 完整表单 |
| Account | 按钮 disabled + spinner | "暂无连接账号" | ErrorBanner | 账号列表 + 表单 |

页面状态优先级：
1. 如果有缓存数据 + 有错误 → 显示缓存数据 + ErrorBanner
2. 如果无缓存数据 + 加载中 → Loading 状态
3. 如果无缓存数据 + 无错误 + 无数据 → Empty 状态
4. 如果加载失败 + 无缓存 → Error 全屏状态

---

## 10. Animation & Motion

```
页面过渡：
  - NavigationStack push: 系统默认 slide
  - Sheet present: 系统默认
  - Tab 切换: 无动画（直接切换）

微交互：
  - 卡片出现：scaleEffect(0.95) → 1.0 + opacity 0 → 1, 0.3s, stagger each 0.05s
  - 数据刷新：卡片数值从旧值动画递增/递减到新值（contentTransition .numericText()）
  - 下拉刷新：系统 RefreshControl
  - ErrorBanner 进出：slide + fade, 0.3s
  - Premium 解锁：遮罩 fade out 0.5s + 内容 scale 0.98→1.0
  - 按钮点击：scaleEffect 0.97, 0.1s spring, 释放回 1.0

禁用动效场景：
  - Reduce Motion 开启时：移除所有 scale/opacity 动画，仅保留必要的 layout 变化
  - 性能不足时：减少 stagger 延迟，去掉 spring
```

---

## 11. Accessibility

```
VoiceOver：
  - 所有卡片：accessibilityLabel = "粉丝数: 12,345, 较上次增长 2.3%"
  - 所有按钮：accessibilityLabel 包含操作说明
  - 图表：accessibilityLabel = "粉丝增长趋势图：6月3日至9日，从12,100增长至12,345"
  - 图标：accessibilityHidden(true)（图标仅装饰）

Dynamic Type：
  - 所有 Text 使用系统 text style（非固定字号）
  - 卡片在 .accessibilityExtraExtraLarge 时从 2 列切换为 1 列
  - 图表高度在 Large 及以上时增加 40pt

Reduce Motion：
  - 检测 @Environment(\.accessibilityReduceMotion)
  - 关闭 skeleton shimmer 动画
  - 关闭卡片 stagger 入场动画
  - 关闭 Liquid Glass blur（静态背景代替）
```

---

## 12. Localization

```
所有 UI 文本通过 L10n key 访问，禁止硬编码字符串。

语言切换行为：
  - Settings → 语言 → 选择 → 立即生效
  - 使用 Bundle-based 运行时切换
  - ContentView 使用 .id(language) 强制重建 view tree
  - 持久化到 UserDefaults

翻译覆盖范围：
  ✅ Dashboard 卡片标签 + 空状态 + 加载文案
  ✅ Trends 图表标题 + 窗口切换标签 + 增长摘要
  ✅ Settings 所有 Section 标题 + 行标签 + Premium 功能名
  ✅ Account 表单标签 + placeholder + 按钮文字
  ✅ ErrorBanner 错误信息模板
  ✅ PremiumGate 升级提示 + 功能描述
  ✅ 导出对话框 + 隐私政策 + 存储说明

支持语言：
  - en (English) — 基准语言
  - zh-Hans (简体中文)
  - zh-Hant (繁体中文)
  - ja (日本語)
```

---

## 13. Theme Switching

```
4 个主题通过 @Environment(\.theme) 注入，全局生效：

  .appleNative    — 系统原生风格，自动适配深色/浅色模式
  .instagram      — Instagram 品牌风格，粉橙渐变体系
  .midnightDark   — 深黑专业风格，冷调蓝强调色
  .instagramDark  — Instagram 深色风格

主题切换：
  - Settings → 主题 → 选择 → 立即生效
  - Theme 是 struct : Sendable，值类型安全跨 actor
  - 持久化到 UserDefaults
  - 切换动画：背景色 0.3s ease 渐变过渡

Theme struct 提供：
  - Color palette (background, text, card, separator, accent)
  - Gradient definitions (chart fill, brand gradient)
  - Chart style tokens
  - Shadow tokens
```

---

## 14. Premium Gating — Visual Rules

```
所有 Premium 功能在 UI 层使用 .premiumGate(feature:) modifier 包裹。

未解锁视觉规范：
  ┌────────────────────────┐
  │ [Normal Card Content]  │
  │  ░░░░ 毛玻璃遮罩 ░░░░   │  ← .ultraThinMaterial, opacity 0.7
  │       🔒              │  ← SF Symbol "lock.fill", 32pt, secondary
  │    Premium 功能        │  ← caption, secondary
  └────────────────────────┘

解锁后视觉规范：
  - 遮罩消失
  - 显示实际数据/图表
  - 如果是首次解锁，卡片有微小的 scale 动画（0.98 → 1.0, 0.4s spring）

一键解锁按钮：
  - 全宽，圆角 12pt
  - 背景：黄色 (#FFCC00)，文字：黑色，semibold
  - 图标：lock.open.fill 左侧
  - 点击后所有 13 个功能标记 enabled=true, expiresAt=nil (永久)
```

---

## 15. Data Export UI

```
导出菜单（从 Dashboard "⋯" 或 Settings "导出数据" 进入）：

┌─────────────────────────────────┐
│ 导出数据                         │
├─────────────────────────────────┤
│                                 │
│ 📄 JSON 导出          [免费]    │  ← 基础功能
│ 📊 CSV 导出           [免费]    │
│ 📈 Excel 导出      🔒 [Premium] │  ← Premium 独占
│                                 │
│ 选择账号：                       │
│ [@zane_liao ▾]                  │  ← Picker
│                                 │
│ 选择时间范围：                    │
│ [最近 7 天 ▾]                   │  ← Picker: 7d / 30d / 90d / All
│                                 │
│           [开始导出]             │  ← 全宽蓝色按钮
│                                 │
│ 导出过程：                       │
│ ⏳ 正在生成文件... 45%           │  ← ProgressView + 百分比
│                                 │
│ 导出完成：                       │
│ ✅ 文件已保存到：                │
│ /var/mobile/.../export.json     │
│           [分享文件]             │  ← ShareLink
└─────────────────────────────────┘
```

---

## 16. Platform Constraints

```
✅ 目标平台：iPhone only (iOS 26+)
❌ 不做 iPad 适配
❌ 不做 macOS / watchOS / visionOS 适配
✅ 竖屏为主（Portrait），可旋转到横屏但不做专门适配
✅ 支持 iPhone SE (小屏) 到 iPhone 17 Pro Max (大屏)
✅ 所有布局使用 GeometryReader / 相对尺寸，无硬编码固定宽度
✅ Safe Area 完整适配
✅ 底部 Tab Bar 适配（不遮挡内容）
```

---

## 17. Design Checklist

在生成任何 UI 代码之前，确认以下内容：

- [ ] 所有文本通过 L10n key 访问，无硬编码字符串
- [ ] 所有颜色通过 @Environment(\.theme) 获取，无硬编码色值
- [ ] 页面的 4 种状态（Loading / Empty / Error / Loaded）均已处理
- [ ] Premium 功能通过 .premiumGate() modifier 控制可见性
- [ ] 图表使用 Swift Charts BarMark（竖条柱状图），非 LineMark
- [ ] Trends 页使用 ScrollView(.vertical)，非 TabView 横向滑动
- [ ] Liquid Glass 效果可降级
- [ ] 所有 SF Symbol 图标名称一致（使用上述规范中的命名）
- [ ] Accessibility 标签完整（VoiceOver + Dynamic Type + Reduce Motion）
- [ ] 组件可复用（StatCard / TrendBarChart / ErrorBanner / EmptyState 均抽取为独立 View）
- [ ] 无 force-unwrap (!)
- [ ] import Combine 显式声明
- [ ] 不直接 import GRDB 在 View 或 ViewModel 中
```

---

## 18. Sample Prompt for AI Code Generators

```
Build an iOS 26+ SwiftUI app called "Follower" — a local-first Instagram analytics tracker.
Use MVVM architecture. All data stays on device.

SCREENS:
1. Splash Screen: Instagram gradient background (#F58529→#DD2A7B→#8134AF→#515BD4 at 45°),
   centered app icon + "Follower" title + tagline "本地优先 · 数据私有", fade-scale in animation

2. Dashboard: 2x4 grid of StatCards (followers, following, media, engagement, likes, comments,
   shares, profile views). Each card shows icon + label + value + change rate (green↑/red↓).
   Pull-to-refresh. Below grid, Premium-only cards (engagement quality score, activity analysis,
   geo distribution) with lock overlay when not unlocked.

3. Trends: Vertical ScrollView with stacked bar charts (Swift Charts BarMark). Segmented picker
   for day/week/month. Each chart is a bar chart showing metric trends. Bar fill uses Instagram
   gradient. Premium "compare" mode shows two bar sets side by side.

4. Settings ("我的"): Trial countdown bar, connected accounts list, Premium feature checklist
   with one-tap unlock button, language picker (en/zh-Hans/zh-Hant/ja), theme picker
   (Apple Native/Instagram/Midnight Dark/Instagram Dark), appearance picker (System/Light/Dark),
   export options, privacy policy, storage info, danger zone (delete all data).

5. Account: Create/delete Instagram accounts. Username text field, display name field,
   save button. Swipe-to-delete account list.

THEMES:
- Apple Native (system colors, auto dark/light)
- Instagram (brand pink-orange-purple gradient, frosted cards)
- Midnight Dark (deep charcoal, cool blue accent)
- Instagram Dark (Instagram palette on dark background)
All colors via @Environment(\.theme). Liquid Glass (.ultraThinMaterial) cards, can be disabled.

CHART DESIGN (Gamma-2):
- Vertical bar charts only (NO line charts)
- Rounded top corners (8pt), slight bottom rounding (2pt)
- Instagram gradient fill (top to bottom)
- ScrollView(.vertical) for multiple charts
- Gap between bars: 4pt

PREMIUM GATING:
- PremiumGate modifier: shows frosted overlay + lock icon when not unlocked
- 13 Premium features, all stored in Metric table
- One-tap unlock button in developer mode (yellow, sets all features enabled)

STATES: Loading (skeleton shimmer), Empty (icon + message + action button),
Error (red banner slides from top, auto-dismiss 3s, retry button), Loaded (actual content)

ACCESSIBILITY: Full VoiceOver labels, Dynamic Type support (2-col→1-col at large sizes),
Reduce Motion support (no animations)

NO: force-unwraps, hardcoded strings, inline colors, line charts, horizontal swiping trends,
TikTok UI elements, iPad layout
```
