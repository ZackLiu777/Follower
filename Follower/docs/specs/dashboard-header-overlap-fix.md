# 仪表盘头像与标题重叠 Bug 修复记录

> **日期**：2026-08-01
> **状态**：已解决
> **分支**：omega

---

## 1. 现象

仪表盘右上角账号头像与「仪表盘」导航栏标题发生**重叠/挤压**：

- 头像按钮被顶部安全区 / Dynamic Island 区域挤压
- toolbar item 与导航标题区域重叠
- 头像与标题不在同一水平线，视觉错位

---

## 2. 根因（多轮排查）

| # | 根因 | 说明 |
|---|------|------|
| 1 | **44pt 头像超出 toolbar 安全高度** | toolbar item 默认高度 ~44pt，44pt 头像 + 毛玻璃 + 阴影实际渲染超出，被 Dynamic Island 挤压 |
| 2 | **复合视图塞入 toolbar** | 原 AccountBar 是 `Menu + Spacer + 头像 Button + .sheet` 复合视图，作为单个 ToolbarItem 时 Spacer 被渲染成占位，导致菜单与头像重叠 |
| 3 | **`.sheet` 挂在 toolbar 内视图上** | toolbar 中的视图没有可靠呈现宿主，点击头像弹窗弹不出或错位 |
| 4 | **`ignoresSafeArea()` 背景侵入导航栏** | 渐变背景延伸到 navigation bar 背后，与半透明导航栏合成冲突 |
| 5 | **⚠️ 核心：toolbar 内 Material 毛玻璃背景** | `Circle().fill(.ultraThinMaterial)` + `theme.cardSurface` + `stroke` 叠层在 Liquid Glass 导航栏内触发合成冲突——这是重叠的直接元凶 |

---

## 3. 修复过程

### 3.1 第一轮：拆分复合 AccountBar

- AccountBar 重构为**纯头像按钮**：无 Spacer / 无 Menu / 无 sheet / 无 padding
- 多账户切换 Menu 移至内容区顶部
- `.sheet` 挂到 DashboardView **根层级**（NavigationStack 之后）

### 3.2 第二轮：toolbar 安全尺寸 + 背景边界

- 头像 44pt → **32pt**（toolbar 标准图标尺寸），图标 18 → 14pt，移除 shadow
- `ignoresSafeArea()` → `ignoresSafeArea(edges: .bottom)`（背景不侵入导航栏）

### 3.3 第三轮：最小布局修复（架构不变）

- ScrollView 内容顶部 padding 8 → **60**（内容不再被导航栏安全区域覆盖）
- 渐变背景恢复 `.ignoresSafeArea()`（Liquid Glass 由系统与导航栏合成）
- toolbar item 外层加 `.frame(width: 32, height: 32)` 双重保险

### 3.4 第四轮（核心修复）：删除 toolbar 内毛玻璃背景

```swift
// ❌ 删除前 — toolbar 内 Liquid Glass 毛玻璃叠层（合成冲突根源）
ZStack {
    Circle().fill(.ultraThinMaterial)        // ← 删除
    Circle().fill(theme.cardSurface)         // ← 删除
    Circle().stroke(theme.divider, lineWidth: 0.5)  // ← 删除
    Image(systemName: "person.fill")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(theme.accentPrimary)
}
.frame(width: 32, height: 32)

// ✅ 删除后 — toolbar 内纯图标（与 Liquid Glass 导航栏无合成冲突）
ZStack {
    Image(systemName: "person.fill")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(theme.accentPrimary)
}
.frame(width: 32, height: 32)
```

---

## 4. 最终结构

```swift
NavigationStack {
    Group {
        if viewModel.latestSnapshot != nil {
            ZStack {
                LinearGradient(colors: theme.backgroundGradientColors, ...)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        // 多账户 Menu（内容区，不进工具栏）
                        // 最近内容 / 指标卡片 / Premium
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 60)   // 避开导航栏
                    .padding(.bottom, 24)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
    .navigationTitle(loc(L10n.Dashboard.title))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
            AccountBar { showProfileSheet = true }   // 纯图标按钮
                .frame(width: 32, height: 32)
        }
    }
    .refreshable { ... }
}
// 个人资料弹窗挂根层级
.sheet(isPresented: $showProfileSheet) { AccountProfileSheet(...) }
```

---

# 第二部分：个人账号弹窗设计系统不一致 Bug

## 7. 现象

个人账号弹窗（AccountProfileSheet）与 Dashboard 观感割裂，像"两个 App"：

- 头像呈"灰色玻璃圈"（旧式 Material 三层叠）
- 卡片高度参差：个人资料 ~112pt / 活动状态 ~72pt / 连接账号 ~88pt / 账号列表 ~88pt / 设置 ~72pt
- 账号列表图标呈灰色（`textSecondary`），与 Dashboard 橙色图标不一致
- 状态颜色混用系统 `.green` / `.red`，未用 `theme.positiveGreen` / `negativeRed`

## 8. 根因

| # | 根因 |
|---|------|
| 1 | **iOS 17 写法 vs iOS 26 Liquid Glass**：`Circle().fill(.ultraThinMaterial) + theme.cardSurface + stroke` 三层叠在 iOS 26 下产生"灰玻璃圈"、卡片颜色不一致 |
| 2 | **Form + Section 行高由内容决定**：各 Row 默认 vertical padding / Label 高度 / HStack intrinsic height 不同 → 5 张卡片高度参差（112/72/88/88/72） |
| 3 | **图标颜色混用**：`theme.textSecondary`（灰）而非 `accentPrimary`；状态用系统 `.green/.red` |
| 4 | **Label 组件 vs 自定义 HStack 混用**：Label 图标尺寸与其他行 HStack 图标不一致 |

## 9. 修复

### 9.1 头像 → iOS 26 Liquid Glass 写法

```swift
// ❌ 旧：Material + cardSurface + divider 三层叠（灰玻璃圈）
ZStack {
    Circle().fill(.ultraThinMaterial)
    Circle().fill(theme.cardSurface)
    Circle().stroke(theme.divider, lineWidth: 0.5)
    Image(systemName: "person.fill")...
}
.frame(width: 44, height: 44)

// ✅ 新：纯 icon + Material 圆底 + 白色描边
Image(systemName: "person.fill")
    .font(.system(size: 20, weight: .medium))
    .foregroundStyle(theme.accentPrimary)
    .frame(width: 44, height: 44)
    .background { Circle().fill(.ultraThinMaterial) }
    .overlay { Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.5) }
```

### 9.2 统一卡片行高度（64pt）

| 卡片 | 修复前 | 修复后 |
|------|:------:|:------:|
| 个人资料 | ~112pt | **64pt** |
| 活动状态 | ~72pt | **64pt** |
| 连接新账号 | ~88pt | **64pt** |
| 账号列表（每行） | ~88pt | **64pt** |
| 设置入口 | ~72pt | **64pt** |

```swift
// 每行统一：
.frame(height: 64)
```

### 9.3 统一 Section 行内边距

```swift
.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
```

### 9.4 图标/颜色统一

- 图标统一 `.font(.system(size: 20))` + `foregroundStyle(theme.accentPrimary)`
- 账号列表未选中：`accentPrimary.opacity(0.6)`（不再用灰色 `textSecondary`）
- 状态徽章：`.green/.red` → `theme.positiveGreen / theme.negativeRed`（AccountProfileSheet + AccountView 一并统一）
- `Label` → 自定义 `HStack`（图标 20pt + subheadline 文字），消除尺寸差异

## 10. 设计规范（沉淀）

### Icon 统一

```swift
.font(.system(size: 18~20, weight: .medium))
.foregroundStyle(theme.accentPrimary)
```

### Glass Avatar 统一

```swift
.background { Circle().fill(.ultraThinMaterial) }
.overlay { Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.5) }
```

### Card 高度统一

```
行高固定 64pt + Section listRowInsets(0, 16, 0, 16)
```

### 禁止

- ❌ toolbar 内 / Liquid Glass 卡片内使用 `Circle().fill(.ultraThinMaterial) + cardSurface + stroke` 三层叠
- ❌ 混用系统色 `.green/.red`（统一 theme 色板）
- ❌ Form 行不设固定高度（行高由内容决定 → 参差）

## 11. 涉及文件

- `Follower/Features/Account/AccountProfileSheet.swift` — 头像写法 / 行高 / 图标 / 颜色 / Label→HStack
- `Follower/Features/Account/AccountView.swift` — 状态徽章与错误文案颜色统一 theme

---

## 12. 第二部分补充教训

1. **设计系统一致性 > 局部好看**：iOS 26 Liquid Glass 下，`ultraThinMaterial + cardSurface + stroke` 三层叠写法会产生"灰玻璃圈"、与 Dashboard 割裂——全 App 统一为「纯 icon + Material 圆底 + 白色描边」
2. **Form 行必须设固定高度**：行高由内容决定会导致卡片参差（112/72/88/88/72）——统一 `frame(height: 64)` + `listRowInsets(0, 16, 0, 16)`
3. **颜色只用 theme 色板**：不混用系统 `.green/.red`、`.textSecondary` 灰色图标
4. **组件统一**：图标 18~20pt `accentPrimary`、玻璃头像规范、卡片行高规范——下一步可抽取 `LiquidGlassCard / LiquidGlassIcon / LiquidGlassAvatar` 三件套组件

1. **toolbar item 必须是最简形态**：单一 Button，无 Spacer / Menu / sheet / 自定义背景
2. **不要给 toolbar 内视图加 Material 毛玻璃**：iOS 26 Liquid Glass 导航栏自己处理玻璃合成，自定义 Material 叠层会冲突
3. **toolbar 图标用安全尺寸**：24–32pt，不要放 44pt 大头像
4. **弹窗呈现（sheet）不要挂 toolbar 内视图**：挂到视图树根部
5. **大头像（44–52pt）适合内容区 / safeAreaInset Header**，不适合 toolbar——若需保留大头像设计，应改用自定义 Header（`safeAreaInset(edge: .top)`）

---

## 6. 涉及文件

- `Follower/Features/Shared/AccountBar.swift` — 重构为纯图标 toolbar 按钮
- `Follower/Features/Dashboard/DashboardView.swift` — toolbar / 内容区 padding / sheet 层级 / 多账户 Menu 迁移
