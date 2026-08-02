# 主题切换不同步 Bug 修复记录（Settings / 个人账号弹窗）

> **日期**：2026-08-01 ~ 2026-08-02
> **状态**：已解决
> **分支**：omega

---

## 1. 现象

切换主题（尤其深色 ↔ 浅色）后出现「半刷新」：

- 页面背景 / Card 已切换到新主题
- 部分文字、Icon、Picker Accent Color 仍停留在旧主题
- **退出弹窗再进入后完全正确**

典型序列：浅色 → Apple Dark（不同步）→ 切回浅色（背景残留深色）。

## 2. 排查过程（多轮验证）

| # | 排查方向 | 结论 |
|---|---------|------|
| 1 | Theme 配置错误 | ❌ 排除（重进后正确） |
| 2 | View 代码写错 | ❌ 排除（同一 View 最终显示正确） |
| 3 | `@State` 缓存 theme / `let theme` 属性快照 | ❌ 代码中不存在 |
| 4 | `.id()` 强制重建丢失状态 | ❌ 无此类代码 |
| 5 | **sheet 环境快照** | ✅ 关键方向：sheet 呈现时捕获环境，主树 `.withTheme` 更新不传播 |
| 6 | **双状态源**（AppState + Environment theme） | ✅ 核心根因之一：两套来源更新时机不一致 |
| 7 | **colorScheme 未同步** | ✅ 核心根因之二：自定义颜色变了，SwiftUI 系统色（`.secondary`/`.primary`/系统控件）仍按旧 colorScheme 渲染 |

**调试确认**（print 日志）：

```
[ThemeDebug] currentTheme changed: instagram → appleDark
[ThemeDebug] SettingsView body — currentTheme: appleDark, isDark: true, bg: [...]   ✅ body 重算且值正确
```

→ **数据流完全同步**，问题不在状态传递，而在渲染层：sheet presentation boundary 没收到系统 colorScheme。

## 3. 根因总结

```
用户切换主题
    ↓
AppState.currentTheme 改变 ✅（@Observable 观察正常）
    ↓
View body 重算 ✅（日志证实）
    ↓
sheet 内的 NavigationStack / Form / 系统色使用旧 Environment ❌
```

三个问题叠加：

1. **双状态源**：`AppState.currentTheme`（自定义色）与 `@Environment(\.theme)`（环境注入）并存，更新时机不一致 → 半刷新
2. **sheet 是独立 presentation root**：不继承父层 `.preferredColorScheme`，`@Environment(\.colorScheme)` 停留在呈现时快照
3. **Theme 里存了动态色**：`textSecondary: .secondary`、`textTertiary: Color(.tertiaryLabel)` 是 colorScheme 依赖的动态色，存进 Theme 后跟随旧环境

## 4. 修复方案（架构级，4 步）

### 4.1 统一状态源：删除弹窗的 `@Environment(\.theme)`

AccountProfileSheet / AccountView / UpgradePromptView 全部改为：

```swift
private var currentTheme: Theme { appState.currentTheme.theme }
```

所有 `theme.xxx` → `currentTheme.xxx`（含三元表达式、Section header、toolbar 按钮），弹窗内不再存在系统色（`.secondary`/`.primary` 清零）。

### 4.2 sheet 根节点注入 colorScheme

sheet 调用处（presentation root）添加：

```swift
.sheet(isPresented: $showProfileSheet) {
    AccountProfileSheet(...)
        .preferredColorScheme(appState.currentTheme.theme.isDark ? .dark : .light)
}
```

覆盖三处：DashboardView → AccountProfileSheet、AccountProfileSheet → AccountView、PremiumGateModifier → UpgradePromptView。

sheet 内容自身显式绑定：

```swift
.environment(\.colorScheme, currentTheme.isDark ? .dark : .light)
```

### 4.3 删除弹窗内部补救 `.themeSynced()`

弹窗内容已是 AppState 单一来源，删除 themeSynced（其 withTheme/tint/colorScheme 注入由 sheet 根 + 显式绑定替代）。主树 ContentView 的 themeSynced 保留（主树视图仍依赖 `@Environment(\.theme)` 注入）。

### 4.4 Theme 动态色清理

| Token | 之前（动态色） | 现在（确定性） |
|-------|--------------|--------------|
| 浅色主题 `textSecondary` | `.secondary` | `.black.opacity(0.6)` |
| 浅色主题 `textTertiary` | `Color(.tertiaryLabel)` | `.black.opacity(0.45)` |
| 深色主题 `textSecondary` | `.secondary` | `.white.opacity(0.65)` |
| 深色主题 `textTertiary` | `Color(.tertiaryLabel)` | `.white.opacity(0.45)` |
| appleNative `textPrimary` | `.primary` | `.black` |

> 教训：`.primary` / `.secondary` / `.tertiaryLabel` 不是颜色，是 `UIColor dynamic provider`（依赖 colorScheme）——不允许存入 Theme。

## 5. 最终架构

```
                AppState
                   |
        ┌──────────┴───────────┐
   currentTheme           colorScheme（isDark 桥）
        |                       |
  自定义颜色                SwiftUI 系统色
        |                       |
   所有 View         sheet 根 preferredColorScheme
```

- 自定义颜色：全部 `appState.currentTheme.theme.xxx` 确定性读取（@Observable 直接观察）
- 系统色（`.secondary`/系统控件）：sheet 根注入 preferredColorScheme + `.environment(\.colorScheme)` 同步
- 主树：ContentView.themeSynced 注入 `@Environment(\.theme)`（主树视图兼容）

## 6. 涉及文件

| 文件 | 改动 |
|------|------|
| `Follower/Core/ThemeSystem.swift` | 6 主题 text 色确定性化；ThemeSyncModifier 保留（主树用） |
| `Follower/Core/AppState.swift` | `currentTheme` didSet 状态机（transitioning → 广播 → synced）+ 调试打印 |
| `Follower/ContentView.swift` | 主树 themeSynced（保留） |
| `Follower/Features/Account/AccountProfileSheet.swift` | 删 @Environment(\.theme) + themeSynced；currentTheme 单一源；colorScheme 绑定；AccountView sheet 加 preferredColorScheme |
| `Follower/Features/Account/AccountView.swift` | 同上（删 themeSynced，加 colorScheme） |
| `Follower/Features/Settings/SettingsView.swift` | currentTheme 单一源；colorScheme 绑定（早期修复，验证有效） |
| `Follower/Features/Shared/PremiumGate.swift` | UpgradePromptView 删 themeSynced + colorScheme 绑定；sheet 调用处 preferredColorScheme |
| `Follower/Features/Shared/AccountBar.swift` | 删 @Environment(\.theme)，currentTheme 单一源 |
| `Follower/Features/Dashboard/DashboardView.swift` | AccountProfileSheet sheet 调用处 preferredColorScheme |

## 7. 关键教训

1. **sheet 是独立 presentation root**——不继承父层 colorScheme / 自定义环境更新，必须在呈现根显式注入
2. **单一状态源**：`AppState.currentTheme` 与 `@Environment(\.theme)` 并存必然产生半刷新，统一为 AppState
3. **动态色不能进 Theme**：`.primary`/`.secondary`/`.tertiaryLabel` 依赖 colorScheme，必须替换为确定性颜色
4. **先验证再修补**：print 日志证明数据流正确后，问题定位从「状态传递」转向「渲染层/环境边界」
5. **主题切换链路**：AppState（单一源）→ 自定义色（确定性读取）+ colorScheme（sheet 根注入）→ 全部视图

## 8. 遗留调试代码

- `AppState.currentTheme` didSet 的 `[ThemeDebug]` print（`#if DEBUG` 包裹）——验证完成后可删除
- `SettingsView` body 的 `[ThemeDebug]` print（`#if DEBUG` 包裹）——同上
