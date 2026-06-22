# 10 套主题设计规范

> Follower App 主题系统 v2。每套主题同时改变屏幕背景、卡片、文字、图表和交互元素的全局配色。
> 保持现有 `Theme` struct 架构，所有颜色通过 `@Environment(\.theme)` 注入。

---

## 主题总览

| # | 主题名称 | 主色调 | 风格关键词 | Liquid Glass |
|---|---------|--------|-----------|:---:|
| 1 | Apple Native | 系统蓝 `#007AFF` | 原生、干净、信任 | ✅ |
| 2 | Instagram | 粉橙渐变 `#DD2A7B` | 社交、活力、温暖 | ✅ |
| 3 | Midnight Pro | 冷蓝 `#0A84FF` | 专业、专注、暗黑 | ❌ |
| 4 | Instagram Noir | 粉橙 `#DD2A7B` | 暗黑社交、沉浸 | ❌ |
| 5 | Warm Amber | 琥珀金 `#E8A838` | 电影感、温暖、高级 | ❌ |
| 6 | Forest | 苔绿 `#4A9E6E` | 自然、平静、舒缓 | ✅ |
| 7 | Ocean | 深海蓝 `#2563EB` | 冷静、深度、专业 | ❌ |
| 8 | Rose Gold | 玫瑰金 `#E8A0B4` | 优雅、柔美、精致 | ✅ |
| 9 | Mono Stone | 石板灰 `#6B7280` | 极简、编辑、永恒 | ❌ |
| 10 | Twilight | 暮光紫 `#8B5CF6` | 创意、梦幻、想象力 | ✅ |

---

## 1. Apple Native

### 视觉身份
> 干净、可信赖的系统原生风格。让你感觉这是 iOS 自带的 App，而不是第三方作品。

### 背景
- 浅色模式：纯白 `#FFFFFF`，干净无纹理
- 深色模式：纯黑 `#000000`，OLED 友好
- 背景不做额外装饰，完全依赖系统语义色

### 卡片
- 浅色：`#F2F2F7` 微灰底色
- 深色：`#1C1C1E` 深灰
- Liquid Glass 开启，`ultraThinMaterial` 毛玻璃

### 完整色板

```
Background Primary:    #FFFFFF (Light) / #000000 (Dark)
Background Secondary:  #F2F2F7 (Light) / #1C1C1E (Dark)
Background Grouped:    #F2F2F7 (Light) / #000000 (Dark)
Card Surface:          #F2F2F7 (Light) / #1C1C1E (Dark)
Card Elevated:         #E5E5EA (Light) / #2C2C2E (Dark)
Text Primary:          #000000 (Light) / #FFFFFF (Dark)
Text Secondary:        rgba(60,60,67,0.6) / rgba(235,235,245,0.6)
Text Tertiary:         rgba(60,60,67,0.3) / rgba(235,235,245,0.3)
Text Inverted:         #FFFFFF / #000000
Accent Primary:        #007AFF
Accent Secondary:      #007AFF 70%
Positive / Growth:     #34C759
Negative / Decline:    #FF3B30
Warning:               #FF9500
Divider:               rgba(60,60,67,0.2) / rgba(84,84,88,0.6)
Navigation Bar:        #FFFFFF (Light) / #000000 (Dark)
Empty State Icon:      #C7C7CC (Light) / #48484A (Dark)

Chart Bar Gradient:    #007AFF → #007AFF 60%
Chart Line:            #007AFF
Chart Area:            #007AFF 15%
Chart Grid:            #E5E5EA (Light) / rgba(255,255,255,0.08) (Dark)

Premium Badge Start:   #FF9500
Premium Badge End:     #FF2D55
Trial Badge:           #FF9500
Locked Badge:          #C7C7CC (Light) / #48484A (Dark)

Button Primary:        #007AFF
Button Destructive:    #FF3B30
Button Disabled:       #C7C7CC (Light) / #48484A (Dark)
```

### 适用场景
日常使用、数据查阅、追求 iOS 原生体验的用户。

---

## 2. Instagram

### 视觉身份
> Instagram 品牌灵魂。粉橙渐变流动于整个界面，提醒你这是一个为 Instagram 创作者打造的工具。

### 背景
- 浅色：`#FAFAFA` Instagram 标志性暖灰白
- 深色：跟随系统，不做强制深色
- 屏幕上方隐约可见极淡的 Instagram 渐变（45°，0.03 不透明度）

### 卡片
- 纯白 95% 不透明度 + 微弱毛玻璃
- 圆角 16pt，阴影极浅
- Liquid Glass 开启

### 完整色板

```
Background Primary:    #FAFAFA (Light) / #0A0A0A (Dark)
Background Secondary:  #F0F0F0 (Light) / #1A1A1A (Dark)
Background Grouped:    #F5F5F5 (Light) / #0D0D0D (Dark)
Card Surface:          #FFFFFF 95% frosted
Card Elevated:         #FFFFFF (Light) / #1E1E1E (Dark)
Text Primary:          #262626 (Light) / #F5F5F5 (Dark)
Text Secondary:        #8E8E8E (Light) / #A8A8A8 (Dark)
Text Tertiary:         #C7C7C7 (Light) / #6E6E6E (Dark)
Text Inverted:         #FFFFFF
Accent Primary:        #DD2A7B (Instagram Pink)
Accent Secondary:      #F58529 (Instagram Orange)
Positive / Growth:     #78DE45
Negative / Decline:    #ED4956
Warning:               #FFDC5C
Divider:               #DBDBDB (Light) / #363636 (Dark)
Navigation Bar:        #FAFAFA (Light) / #0A0A0A (Dark)
Empty State Icon:      #C7C7C7 (Light) / #48484A (Dark)

Chart Bar Gradient:    #F58529 → #DD2A7B (Instagram 渐变)
Chart Line:            #DD2A7B
Chart Area:            #DD2A7B 15%
Chart Grid:            #DBDBDB (Light) / #363636 (Dark)

Premium Badge Start:   #F58529
Premium Badge End:     #DD2A7B
Trial Badge:           #F58529
Locked Badge:          #C7C7C7
```

### 适用场景
内容创作者、Instagram 重度用户、喜欢温暖品牌调性的用户。

---

## 3. Midnight Pro

### 视觉身份
> 为深夜工作设计的专业级暗黑主题。零炫光、零干扰、极致专注。

### 背景
- 深炭黑 `#0D0D0F`，接近 OLED 黑
- 无纹理、无渐变、无装饰
- 极致简约——只保留数据和功能

### 卡片
- 比背景略微抬升的深灰 `#161618`
- 90% 不透明度 + 微弱毛玻璃
- Liquid Glass 关闭（以性能优先）

### 完整色板

```
Background Primary:    #0D0D0F
Background Secondary:  #161618
Background Grouped:    #0A0A0C
Card Surface:          #161618 90% frosted
Card Elevated:         #1E1E21
Text Primary:          #F0F0F2
Text Secondary:        #98989E
Text Tertiary:         #636369
Text Inverted:         #0D0D0F
Accent Primary:        #0A84FF (Cool Blue)
Accent Secondary:      #0A84FF 70%
Positive / Growth:     #30C85A
Negative / Decline:    #FF453A
Warning:               #FF9F0A
Divider:               #2A2A2E
Navigation Bar:        #0D0D0F
Empty State Icon:      rgba(255,255,255,0.12)

Chart Bar Gradient:    #0A84FF → #0A84FF 50%
Chart Line:            #0A84FF
Chart Area:            #0A84FF 12%
Chart Grid:            #2A2A2E

Premium Badge Start:   #FF9F0A
Premium Badge End:     #FF6B6B
Trial Badge:           #FF9F0A
Locked Badge:          rgba(255,255,255,0.15)

Button Primary:        #0A84FF
Button Destructive:    #E04444
Button Disabled:       rgba(255,255,255,0.10)
```

### 适用场景
夜间工作、数据分析师、追求无干扰专注体验的用户。

---

## 4. Instagram Noir

### 视觉身份
> Instagram 的暗黑面。粉橙暖色在深黑背景上燃烧，像霓虹灯在夜空中。

### 背景
- 纯黑 `#0A0A0A`
- 极淡 Instagram 渐变叠加（0.05 不透明度，仅屏幕中央）
- 底部有微弱的径向渐变光晕（accent 色，0.03）

### 卡片
- 比背景亮 8% 的深灰 `#121212`
- 85% 不透明度毛玻璃
- 边缘有极淡的粉色描边（0.05 不透明度）

### 完整色板

```
Background Primary:    #0A0A0A
Background Secondary:  #121212
Background Grouped:    #070707
Card Surface:          #121212 85% frosted
Card Elevated:         #1A1A1A
Text Primary:          #F5F5F5
Text Secondary:        #A8A8A8
Text Tertiary:         #6E6E6E
Text Inverted:         #0A0A0A
Accent Primary:        #DD2A7B
Accent Secondary:      #F58529
Positive / Growth:     #78DE45
Negative / Decline:    #FF453A
Warning:               #FFDC5C
Divider:               #262626
Navigation Bar:        #0A0A0A
Empty State Icon:      rgba(255,255,255,0.12)

Chart Bar Gradient:    #F58529 → #DD2A7B
Chart Line:            #DD2A7B
Chart Area:            #DD2A7B 15%
Chart Grid:            #262626

Premium Badge Start:   #F58529
Premium Badge End:     #DD2A7B
Trial Badge:           #F58529
Locked Badge:          rgba(255,255,255,0.15)

Button Primary:        #DD2A7B
Button Destructive:    #E04444
Button Disabled:       rgba(255,255,255,0.10)
```

### 适用场景
夜间社交媒体浏览、Instagram 重度用户深色模式。

---

## 5. Warm Amber · 琥珀暖金

### 视觉身份
> 电影级的暗金质感。像老式胶片放映机的光晕，温暖、厚重、有故事感。截图所示风格的核心主题。

### 背景
- 深暖炭黑 `#14110E`（带极微量暖色调的黑色）
- 微弱胶片颗粒纹理（CSS `noise` 滤镜，0.02 不透明度）
- 屏幕上方有极淡的琥珀色光晕（径向渐变，暖金 `#E8A838`，0.04 不透明度）

### 卡片
- 暖深灰 `#1C1916` 半透明
- 80% 不透明度 + 微弱模糊
- 边缘有暖金微光（shadow 使用 `#E8A838` 0.03）
- 类似电影字幕卡片的质感

### 完整色板

```
Background Primary:    #14110E (Warm Charcoal)
Background Secondary:  #1C1916
Background Grouped:    #0F0C0A
Card Surface:          #1C1916 80% frosted
Card Elevated:         #241F1B
Text Primary:          #F0ECE6 (Warm White)
Text Secondary:        #A09888 (Warm Gray)
Text Tertiary:         #6B6356 (Warm Dark Gray)
Text Inverted:         #14110E
Accent Primary:        #E8A838 (Amber Gold)
Accent Secondary:      #D4893A (Deep Amber)
Positive / Growth:     #7EB356 (Muted Green)
Negative / Decline:    #C45A3C (Terracotta Red)
Warning:               #E8A838
Divider:               #2A2520 (Warm Divider)
Navigation Bar:        #14110E
Empty State Icon:      rgba(232,168,56,0.20)

Chart Bar Gradient:    #E8A838 → #D4893A (Amber Gradient)
Chart Line:            #E8A838
Chart Area:            #E8A838 15%
Chart Grid:            #2A2520

Premium Badge Start:   #E8A838
Premium Badge End:     #D4893A
Trial Badge:           #E8A838
Locked Badge:          rgba(255,255,255,0.10)

Button Primary:        #E8A838
Button Destructive:    #C45A3C
Button Disabled:       rgba(232,168,56,0.12)
```

### 关键视觉效果
- **胶片颗粒感**：背景叠加极低不透明度的 noise pattern
- **暖光光晕**：屏幕顶部 1/4 处有径向渐变暖光
- **金边阴影**：卡片阴影使用暖金色而非纯黑
- **Tab Bar**：半透明暖黑 + 选中项琥珀光

### 适用场景
追求独特审美的用户、喜欢暗金/胶片风格、让 App 看起来像一个高级数据工作室。

---

## 6. Forest · 森林

### 视觉身份
> 走进森林。呼吸放缓，专注力提升。深绿与苔藓色的组合让人平静。

### 背景
- 深墨绿 `#0F1A14`
- 微弱的绿色调渐变（从顶部深绿到底部墨绿）
- 无纹理，保持干净

### 卡片
- 深绿灰 `#18261E` 半透明
- Liquid Glass 开启
- 圆角和阴影保持柔和

### 完整色板

```
Background Primary:    #0F1A14 (Deep Forest)
Background Secondary:  #18261E
Background Grouped:    #0B140F
Card Surface:          #1A2E22 frosted
Card Elevated:         #1F3528
Text Primary:          #E8EEE9
Text Secondary:        #9AB5A3
Text Tertiary:         #5C7A65
Text Inverted:         #0F1A14
Accent Primary:        #4A9E6E (Moss Green)
Accent Secondary:      #6DBF8A (Light Moss)
Positive / Growth:     #4A9E6E
Negative / Decline:    #C45A4A (Muted Red)
Warning:               #C4A43A (Muted Gold)
Divider:               #1F3528
Navigation Bar:        #0F1A14
Empty State Icon:      rgba(74,158,110,0.20)

Chart Bar Gradient:    #6DBF8A → #4A9E6E (Green Gradient)
Chart Line:            #4A9E6E
Chart Area:            #4A9E6E 15%
Chart Grid:            #1F3528

Premium Badge Start:   #6DBF8A
Premium Badge End:     #4A9E6E
Trial Badge:           #6DBF8A
Locked Badge:          rgba(255,255,255,0.10)

Button Primary:        #4A9E6E
Button Destructive:    #C45A4A
Button Disabled:       rgba(74,158,110,0.12)
```

### 适用场景
放松浏览数据、长时间使用不疲劳、喜欢自然色调的用户。

---

## 7. Ocean · 深海

### 视觉身份
> 深海般的沉浸感。深蓝从钴蓝渐变到墨蓝，像潜入数据的海洋。冷静、深邃、专注。

### 背景
- 深海军蓝 `#0A1628`
- 从顶部深蓝 `#0F2744` 到底部墨蓝 `#0A1628` 的纵向渐变
- 渐变极微妙（0.5 不透明度差），仅提供深度感

### 卡片
- 深蓝灰 `#12233B` 半透明
- Liquid Glass 关闭
- 微弱的蓝色阴影（`#2563EB` 0.03）

### 完整色板

```
Background Primary:    #0A1628 (Deep Navy)
Background Secondary:  #12233B
Background Grouped:    #07101C
Card Surface:          #12233B 85%
Card Elevated:         #192D4A
Text Primary:          #E8EDF5
Text Secondary:        #94AAC4
Text Tertiary:         #557192
Text Inverted:         #0A1628
Accent Primary:        #3B82F6 (Ocean Blue)
Accent Secondary:      #60A5FA (Sky Blue)
Positive / Growth:     #34D399
Negative / Decline:    #F87171
Warning:               #FBBF24
Divider:               #1A3350
Navigation Bar:        #0A1628
Empty State Icon:      rgba(59,130,246,0.18)

Chart Bar Gradient:    #60A5FA → #3B82F6
Chart Line:            #3B82F6
Chart Area:            #3B82F6 12%
Chart Grid:            #1A3350

Premium Badge Start:   #60A5FA
Premium Badge End:     #3B82F6
Trial Badge:           #60A5FA
Locked Badge:          rgba(255,255,255,0.12)

Button Primary:        #3B82F6
Button Destructive:    #F87171
Button Disabled:       rgba(59,130,246,0.10)
```

### 适用场景
数据分析、长期趋势观察、需要冷静专注氛围的场景。

---

## 8. Rose Gold · 玫瑰金

### 视觉身份
> 精致、优雅、柔和。像玫瑰金首饰的光泽。温暖的粉色调拥抱你。

### 背景
- 暖浅灰 `#F8F4F2`（Light）/ 暖深灰 `#1C1818`（Dark）
- 极淡的玫瑰色渐变（顶部至底部，0.02 不透明度）
- 轻柔的粉色调光晕

### 卡片
- 纯白（Light）/ 暖深灰（Dark）85% 毛玻璃
- Liquid Glass 开启
- 阴影使用暖粉色调

### 完整色板

```
Background Primary:    #F8F4F2 (Light) / #1C1818 (Dark)
Background Secondary:  #F0ECEA (Light) / #242020 (Dark)
Background Grouped:    #EDE8E5 (Light) / #151212 (Dark)
Card Surface:          #FFFFFF 90% frosted / #242020 85% frosted
Card Elevated:         #F5F0ED (Light) / #2C2626 (Dark)
Text Primary:          #2C2428 (Light) / #F0E8EC (Dark)
Text Secondary:        #8C7C84 (Light) / #B0A0A8 (Dark)
Text Tertiary:         #B8A8B0 (Light) / #6C5C64 (Dark)
Text Inverted:         #FFFFFF
Accent Primary:        #D4879A (Rose Pink)
Accent Secondary:      #E8B0C0 (Light Rose)
Positive / Growth:     #7EB896
Negative / Decline:    #D4877A
Warning:               #D4B87A
Divider:               #E8DCD8 (Light) / #302828 (Dark)
Navigation Bar:        #F8F4F2 (Light) / #1C1818 (Dark)
Empty State Icon:      rgba(212,135,154,0.25)

Chart Bar Gradient:    #E8B0C0 → #D4879A
Chart Line:            #D4879A
Chart Area:            #D4879A 15%
Chart Grid:            #E8DCD8 (Light) / #302828 (Dark)

Premium Badge Start:   #E8B0C0
Premium Badge End:     #D4879A
Trial Badge:           #D4879A
Locked Badge:          rgba(212,135,154,0.18)

Button Primary:        #D4879A
Button Destructive:    #D4877A
Button Disabled:       rgba(212,135,154,0.15)
```

### 适用场景
追求柔和视觉体验、不喜欢高对比度暗黑模式的用户。

---

## 9. Mono Stone · 石板灰

### 视觉身份
> 极简。完全剔除色彩，只剩灰度层级。像一本精美的黑白摄影书，让数据本身成为主角。

### 背景
- 中性石板灰 `#F2F1F0`（Light）/ `#1A1A1C`（Dark）
- 零色彩倾向，纯中性灰度
- 无渐变、无纹理

### 卡片
- 纯白（Light）/ 中性深灰（Dark）
- 无毛玻璃效果（Liquid Glass 关闭）
- 仅用灰度阴影表达层级

### 完整色板

```
Background Primary:    #F2F1F0 (Light) / #1A1A1C (Dark)
Background Secondary:  #E8E7E6 (Light) / #242426 (Dark)
Background Grouped:    #EDECEB (Light) / #141416 (Dark)
Card Surface:          #FFFFFF (Light) / #242426 (Dark)
Card Elevated:         #F5F5F4 (Light) / #2E2E30 (Dark)
Text Primary:          #1A1A1C (Light) / #F2F1F0 (Dark)
Text Secondary:        #6B6B6E (Light) / #A0A0A4 (Dark)
Text Tertiary:         #A0A0A4 (Light) / #606064 (Dark)
Text Inverted:         #F2F1F0 (Light) / #1A1A1C (Dark)
Accent Primary:        #48484C (Light) / #D0D0D4 (Dark)
Accent Secondary:      #6B6B6E (Light) / #A0A0A4 (Dark)
Positive / Growth:     #4A4A4E
Negative / Decline:    #6A4A4A
Warning:               #6A6A4A
Divider:               #D8D8D6 (Light) / #2E2E30 (Dark)
Navigation Bar:        #F2F1F0 (Light) / #1A1A1C (Dark)
Empty State Icon:      rgba(0,0,0,0.12) / rgba(255,255,255,0.10)

Chart Bar Gradient:    #48484C → #6B6B6E
Chart Line:            #48484C
Chart Area:            #48484C 12%
Chart Grid:            #D8D8D6 (Light) / #2E2E30 (Dark)

Premium Badge Start:   #48484C
Premium Badge End:     #242426
Trial Badge:           #48484C
Locked Badge:          rgba(0,0,0,0.08) / rgba(255,255,255,0.08)

Button Primary:        #48484C (Light) / #D0D0D4 (Dark)
Button Destructive:    #6A4A4A
Button Disabled:       rgba(0,0,0,0.06) / rgba(255,255,255,0.06)
```

### 适用场景
数据优先的用户、喜欢极简风格、需要中立审美的场景（如截图分享到社交平台）。

---

## 10. Twilight · 暮光紫

### 视觉身份
> 暮光时刻的天空。从靛蓝渐变到紫罗兰，充满创造力和想象力。为思考和灵感而生。

### 背景
- 深靛蓝紫 `#12101C`
- 从底部紫罗兰 `#2D1B4E` 到顶部深靛蓝 `#12101C` 的纵向渐变
- 微弱的星光效果（极小的白色散点，0.01 不透明度）

### 卡片
- 深紫灰 `#1C1A2A` 半透明
- Liquid Glass 开启，产生梦幻的折射效果
- 边缘有极淡的紫色光晕

### 完整色板

```
Background Primary:    #12101C (Deep Indigo)
Background Secondary:  #1C1A2A
Background Grouped:    #0D0B14
Card Surface:          #1C1A2A frosted
Card Elevated:         #242036
Text Primary:          #EDEAF5
Text Secondary:        #A89DC4
Text Tertiary:         #6B5C8C
Text Inverted:         #12101C
Accent Primary:        #8B5CF6 (Twilight Purple)
Accent Secondary:      #A78BFA (Light Purple)
Positive / Growth:     #6EE7B7
Negative / Decline:    #FCA5A5
Warning:               #FCD34D
Divider:               #2A2440
Navigation Bar:        #12101C
Empty State Icon:      rgba(139,92,246,0.20)

Chart Bar Gradient:    #A78BFA → #8B5CF6 (Purple Gradient)
Chart Line:            #8B5CF6
Chart Area:            #8B5CF6 12%
Chart Grid:            #2A2440

Premium Badge Start:   #A78BFA
Premium Badge End:     #8B5CF6
Trial Badge:           #8B5CF6
Locked Badge:          rgba(255,255,255,0.10)

Button Primary:        #8B5CF6
Button Destructive:    #FCA5A5
Button Disabled:       rgba(139,92,246,0.10)
```

### 适用场景
创意工作者、夜晚灵感时间、喜欢非传统配色的用户。

---

## 主题速查矩阵

| 色板 | Apple Native | Instagram | Midnight Pro | Instagram Noir | Warm Amber | Forest | Ocean | Rose Gold | Mono Stone | Twilight |
|------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **背景亮度** | 亮/暗 | 亮/暗 | 暗 | 暗 | 暗 | 暗 | 暗 | 亮/暗 | 亮/暗 | 暗 |
| **Liquid Glass** | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ | ✅ |
| **色温** | 中性 | 暖 | 冷 | 暖 | 暖金 | 中冷 | 冷 | 暖 | 中性 | 中性偏冷 |
| **对比度** | 高 | 中高 | 高 | 中高 | 中 | 中 | 高 | 低 | 高 | 中 |
| **视觉复杂度** | 低 | 中 | 低 | 中 | 高 | 低 | 低 | 中 | 极低 | 中 |

---

## 背景处理分类

### 类型 A：纯色背景（4 套）
- Apple Native、Midnight Pro、Mono Stone、Forest
- 单色背景，依赖卡片层级和阴影表达深度
- 性能最优，适合所有设备

### 类型 B：渐变背景（4 套）
- Ocean（深蓝纵向渐变）、Twilight（靛紫纵向渐变）
- Instagram Noir（品牌渐变叠加）、Warm Amber（径向光晕）
- 提供深度感和沉浸感
- 性能影响可忽略（SwiftUI `LinearGradient` 是 GPU 加速的）

### 类型 C：纹理/光晕背景（2 套）
- Warm Amber（胶片颗粒 + 暖金光晕）
- Instagram（极淡品牌渐变叠加）
- 视觉最丰富，需要额外渲染开销
- 在 Reduce Motion 或旧设备上自动降级为纯色

---

## 迁移从 4 主题到 10 主题

### 新 AppTheme 枚举值

```swift
enum AppTheme: String, CaseIterable {
    case appleNative      // 1
    case instagram        // 2
    case midnightPro      // 3 (原名 midnight)
    case instagramNoir    // 4 (原名 instagramDark)
    case warmAmber        // 5 新增
    case forest           // 6 新增
    case ocean            // 7 新增
    case roseGold         // 8 新增
    case monoStone        // 9 新增
    case twilight         // 10 新增
}
```

### 需要新增的 L10n Key

```
settings.appleNative       → "Apple Native"
settings.instagram         → "Instagram"
settings.midnightPro       → "Midnight Pro"
settings.instagramNoir     → "Instagram Noir"
settings.warmAmber         → "Warm Amber"
settings.forest            → "Forest"
settings.ocean             → "Ocean"
settings.roseGold          → "Rose Gold"
settings.monoStone         → "Mono Stone"
settings.twilight          → "Twilight"
```

### 向后兼容

- `midnight` 重命名为 `midnightPro`（功能不变，仅改名）
- `instagramDark` 重命名为 `instagramNoir`（功能不变，仅改名）
- 旧 UserDefaults 值的迁移由 `AppTheme.init(rawValue:)` 处理，旧 key 映射到新 key
- 4 个已有主题的色值不完全改变，保持用户已有偏好

---

## 实现优先级

| 优先级 | 主题 | 理由 |
|:---:|------|------|
| P0 | Warm Amber | 用户截图明确要求，核心新主题 |
| P1 | Ocean、Forest | 用户需求明确（深蓝/绿色调） |
| P2 | Rose Gold、Twilight、Mono Stone | 扩展选择多样性 |
| P3 | 已有 4 主题重命名 | 同步完成命名规范化 |

---

*最后更新：2026-06-21。本文档为纯设计规范，代码实现将严格遵循此色板和布局规则。*
