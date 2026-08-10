//
//  ThemeSystem.swift
//  Follower
//
//  Lambda-2: 6 套主题。isDark 驱动 preferredColorScheme，渐变背景 + 毛玻璃卡片。
//

import SwiftUI

// MARK: - Theme

/// 主题色板 — 定义背景、文字、图表、徽章、按钮等全套颜色 token
struct Theme: Sendable {
    /// 背景渐变（多色支持）— 页面背景渐变使用的颜色数组，通常 3 色
    let backgroundGradientColors: [Color]
    let backgroundPrimary: Color
    let backgroundSecondary: Color
    let backgroundGrouped: Color
    let backgroundGradientStart: Color
    let backgroundGradientEnd: Color
    let cardSurface: Color
    let cardElevated: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textInverted: Color
    let accentPrimary: Color
    let accentSecondary: Color
    let positiveGreen: Color
    let negativeRed: Color
    let warningOrange: Color
    let chartLine: Color
    let chartArea: Color
    let chartGrid: Color
    let chartBarGradientStart: Color
    let chartBarGradientEnd: Color
    let badgePremiumStart: Color
    let badgePremiumEnd: Color
    /// Premium 卡片背景 — 各主题品牌色柔和半透明版（玻璃质感保留，仅替换静态填充色）
    let premiumCardBackground: Color
    /// Recent Content 卡片背景 — 主题品牌色低透明档（层次弱于 Premium，形成主次）
    let recentContentCardBackground: Color
    /// Dashboard Posts 卡片背景 — 与 Recent Content 同档（当前同值，可独立调整）
    let postsCardBackground: Color
    /// 决策时间线卡片背景 — 主题次品牌色低透明档
    let decisionCardBackground: Color
    let badgeTrial: Color
    let badgeLocked: Color
    let buttonPrimaryBg: Color
    let buttonDestructiveBg: Color
    let buttonDisabledFg: Color
    let divider: Color
    let navigationBg: Color
    let emptyStateIcon: Color
    /// 内容区域表面色（Posts / Premium 列表背景）
    var surface: Color { backgroundSecondary }
    /// 主题展示名称
    let displayName: String
    /// 是否启用 Liquid Glass 毛玻璃效果
    let liquidGlassEnabled: Bool
    /// 深色模式标志 — 驱动 preferredColorScheme
    let isDark: Bool

    // MARK: - Apple Native（明亮天蓝 → 浅蓝渐变，高级玻璃卡片）

    static let appleNative: Theme = {
        // 1. 提炼 Apple 官方设计语言的标准 SF Colors
        let appleSFBlue = Color(red: 0/255, green: 122/255, blue: 255/255)   // Apple 经典 San Francisco Blue (#007AFF)
        let appleSFCyan = Color(red: 50/255, green: 173/255, blue: 230/255)   // SF Soft Cyan (#32ADE6)

        return Theme(
            // 背景渐变：天蓝 → 柔和天空蓝 → 浅青（移除原先断层的纯白，不透明度控制在 0.10 ~ 0.14，沉浸感极强）
            backgroundGradientColors: [
                appleSFBlue.opacity(0.14),
                appleSFBlue.opacity(0.08),
                appleSFCyan.opacity(0.12)
            ],
            backgroundPrimary: Color(.systemBackground),
            backgroundSecondary: Color(.secondarySystemBackground),
            backgroundGrouped: Color(.systemGroupedBackground),
            
            backgroundGradientStart: appleSFBlue.opacity(0.14),
            backgroundGradientEnd: appleSFCyan.opacity(0.12),
            
            // 关键重构：卡片使用半透明纯白！在带有蓝调的背景上，白色的卡片会非常清透、自然凸显
            cardSurface: Color.white.opacity(0.70),
            cardElevated: Color.white.opacity(0.90),
            
            textPrimary: .black,
            textSecondary: .black.opacity(0.60),
            textTertiary: .black.opacity(0.45),
            textInverted: .white,
            
            // 品牌与强调色：经典的 iOS 极简蓝色调
            accentPrimary: appleSFBlue,
            accentSecondary: appleSFCyan,
            
            positiveGreen: .green,
            negativeRed: .red,
            warningOrange: .orange,
            
            chartLine: appleSFBlue,
            chartArea: appleSFBlue.opacity(0.10),
            chartGrid: Color(.systemGray5),
            
            // 图表 & 徽章：渐变过渡自然
            chartBarGradientStart: appleSFBlue,
            chartBarGradientEnd: appleSFCyan,
            badgePremiumStart: appleSFBlue,
            badgePremiumEnd: appleSFCyan,
            premiumCardBackground: appleSFBlue.opacity(0.10),
            recentContentCardBackground: appleSFBlue.opacity(0.07),
            postsCardBackground: appleSFBlue.opacity(0.07),
            decisionCardBackground: appleSFCyan.opacity(0.07),
            badgeTrial: appleSFBlue,
            badgeLocked: Color(.systemGray3),
            
            buttonPrimaryBg: appleSFBlue,
            buttonDestructiveBg: .red,
            buttonDisabledFg: Color(.systemGray3),
            
            divider: Color(.separator),
            navigationBg: Color(.systemBackground),
            emptyStateIcon: Color(.systemGray3),
            
            displayName: "Apple Native",
            liquidGlassEnabled: true,
            isDark: false
        )
    }()
    
    // MARK: - Instagram（高饱和通透日落鲜彩）
    static let instagram: Theme = {
        // 1. 剔除洋红/暗紫，选用极具活力与透光感的高饱和色彩组合
        let instaYellow = Color(red: 255/255, green: 205/255, blue: 60/255)  // 鲜亮阳光黄
        let instaOrange = Color(red: 255/255, green: 110/255, blue: 50/255)  // 高饱和霓虹暖橙
        let instaBrightPink = Color(red: 0xE8 / 255.0, green: 0xA3 / 255.0, blue: 0x9C / 255.0)

        return Theme(
            // 背景渐变：采用“暖黄 → 亮橙 → 活力鲜粉”三色微光，营造明快通透的主题氛围
            backgroundGradientColors: [
                instaYellow.opacity(0.18),
                instaOrange.opacity(0.15),
                instaBrightPink.opacity(0.12)
            ],
            backgroundPrimary: Color(.systemBackground),
            backgroundSecondary: Color(.secondarySystemBackground),
            backgroundGrouped: Color(.systemGroupedBackground),
            
            backgroundGradientStart: instaYellow.opacity(0.18),
            backgroundGradientEnd: instaBrightPink.opacity(0.12),
            
            // 卡片表面：保持 82% / 92% 的高不透明度白色基底，确保浅色毛玻璃下的文字清晰可读
            cardSurface: Color.white.opacity(0.9),
            cardElevated: Color.white.opacity(0.9),
            
            // 文本颜色
            textPrimary: instaBrightPink,
            textSecondary: instaBrightPink,
            textTertiary: instaBrightPink,
            textInverted: .white,
            
            // 主强调色：使用高饱和活力鲜粉与霓虹暖橙作为双强调色
            accentPrimary: instaBrightPink,
            accentSecondary: instaOrange,
            
            positiveGreen: .green,
            negativeRed: .red,
            warningOrange: instaOrange,
            
            // 图表：主线条采用鲜粉色
            chartLine: instaBrightPink,
            chartArea: instaBrightPink.opacity(0.12),
            chartGrid: Color.gray.opacity(0.15),
            
            // 图表柱状图 & 徽章渐变：霓虹暖橙 → 活力鲜粉（高饱和亮色渐变）
            chartBarGradientStart: instaOrange,
            chartBarGradientEnd: instaBrightPink,
            badgePremiumStart: instaOrange,
            badgePremiumEnd: instaBrightPink,
            premiumCardBackground: Color.white,
            recentContentCardBackground: Color.white,
            postsCardBackground: Color.white,
            decisionCardBackground: Color.white,
            badgeTrial: instaOrange,
            badgeLocked: Color(.systemGray3),
            
            // 按钮：主按钮采用高亮鲜粉
            buttonPrimaryBg: instaBrightPink,
            buttonDestructiveBg: .red,
            buttonDisabledFg: Color(.systemGray3),
            
            divider: Color.gray.opacity(0.15),
            navigationBg: Color(.systemBackground),
            emptyStateIcon: Color.gray.opacity(0.4),
            
            displayName: "Instagram",
            liquidGlassEnabled: true,
            isDark: false
        )
    }()
    
    // MARK: - Apple Dark（深黑 → 暗蓝渐变）
    static let appleDark =  Theme(
        // 背景渐变（深灰阶跃，不带任何杂色蓝）
        backgroundGradientColors: [
            Color(red: 0.10, green: 0.10, blue: 0.12),
            Color(red: 0.05, green: 0.05, blue: 0.07),
            .black
        ],
        backgroundPrimary: Color(red: 0.01, green: 0.01, blue: 0.02),
        backgroundSecondary: Color(red: 0.06, green: 0.06, blue: 0.08),
        backgroundGrouped: .black,
        backgroundGradientStart: Color(red: 0.10, green: 0.10, blue: 0.12),
        backgroundGradientEnd: .black,

        // Liquid Glass 卡片：克制透明度，突出毛玻璃质感
        cardSurface: Color.white.opacity(0.06),
        cardElevated: Color.white.opacity(0.13),

        // 文字灰度细腻递增
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.70),
        textTertiary: Color.white.opacity(0.45),
        textInverted: .black,

        // 核心：暖金作为唯一视觉锚点
        accentPrimary: Color(red: 0.94, green: 0.72, blue: 0.30),   // 暖金
        accentSecondary: Color(red: 0.55, green: 0.58, blue: 0.65), // 冷灰（平衡作用）

        positiveGreen: Color(red: 0.20, green: 0.80, blue: 0.55),
        negativeRed: Color(red: 0.95, green: 0.40, blue: 0.30),
        warningOrange: Color(red: 0.95, green: 0.60, blue: 0.20),

        // 图表全系跟随暖金
        chartLine: Color(red: 0.94, green: 0.72, blue: 0.30),
        chartArea: Color(red: 0.94, green: 0.72, blue: 0.30).opacity(0.12),
        chartGrid: Color.white.opacity(0.10),
        chartBarGradientStart: Color(red: 0.94, green: 0.72, blue: 0.30),
        chartBarGradientEnd: Color(red: 0.70, green: 0.50, blue: 0.20),

        // Badge 用渐变金
        badgePremiumStart: Color(red: 0.94, green: 0.72, blue: 0.30),
        badgePremiumEnd: Color(red: 0.85, green: 0.55, blue: 0.15),

        // 卡片背景透明，彻底交给父层和 Liquid Glass
        premiumCardBackground: .clear,
        recentContentCardBackground: .clear,
        postsCardBackground: .clear,
        decisionCardBackground: .clear,

        badgeTrial: Color(red: 0.94, green: 0.72, blue: 0.30),
        badgeLocked: Color.white.opacity(0.25),

        buttonPrimaryBg: Color(red: 0.94, green: 0.72, blue: 0.30),
        buttonDestructiveBg: Color(red: 0.95, green: 0.40, blue: 0.30),
        buttonDisabledFg: Color.white.opacity(0.25),

        divider: Color.white.opacity(0.10),
        navigationBg: Color(red: 0.01, green: 0.01, blue: 0.02),
        emptyStateIcon: Color.white.opacity(0.40),

        displayName: "Luxe Graphite",
        liquidGlassEnabled: true,
        isDark: true
    )
    // MARK: - Forest（鲜亮薄荷绿 → 柔白翠绿）

    static let forest = Theme(
        // 背景渐变（三色）：鲜亮薄荷 → 翠绿 → 柔白
        backgroundGradientColors: [
            .mint.opacity(0.40),
            .green.opacity(0.20),
            .white
        ],
        backgroundPrimary: .mint.opacity(0.15),
        backgroundSecondary: .mint.opacity(0.10),
        backgroundGrouped: .mint.opacity(0.08),
        backgroundGradientStart: .mint.opacity(0.40),
        backgroundGradientEnd: .white,
        cardSurface: .white.opacity(0.40),
        cardElevated: .white.opacity(0.65),
        textPrimary: .black.opacity(0.85),
        textSecondary: .black.opacity(0.6),
        textTertiary: .black.opacity(0.45), textInverted: .white,
        accentPrimary: .green,
        accentSecondary: .mint,
        positiveGreen: .green,
        negativeRed: .red,
        warningOrange: .orange,
        chartLine: .green,
        chartArea: .green.opacity(0.12),
        chartGrid: .gray.opacity(0.15),
        chartBarGradientStart: .mint,
        chartBarGradientEnd: .green,
        badgePremiumStart: .mint,
        badgePremiumEnd: .green,
        premiumCardBackground: .mint.opacity(0.12),
        recentContentCardBackground: .mint.opacity(0.08),
        postsCardBackground: .mint.opacity(0.08),
        decisionCardBackground: .green.opacity(0.08),
        badgeTrial: .mint, badgeLocked: .gray.opacity(0.30),
        buttonPrimaryBg: .green,
        buttonDestructiveBg: .red,
        buttonDisabledFg: .gray.opacity(0.30),
        divider: .gray.opacity(0.15),
        navigationBg: .mint.opacity(0.15), emptyStateIcon: .gray.opacity(0.40),
        displayName: "Forest", liquidGlassEnabled: true, isDark: false
    )

    // MARK: - Mono Stone（暖灰 → 净白，非 Liquid Glass）

    static let monoStone = Theme(
        // 背景渐变（三色）：净白 → 浅灰 → 中灰
        backgroundGradientColors: [
            .gray.opacity(0.05),
            .gray.opacity(0.15),
            .gray.opacity(0.28)
        ],
        backgroundPrimary: .gray.opacity(0.08),
        backgroundSecondary: .gray.opacity(0.12),
        backgroundGrouped: .gray.opacity(0.10),
        backgroundGradientStart: .gray.opacity(0.05),
        backgroundGradientEnd: .gray.opacity(0.28),
        cardSurface: .white.opacity(0.70),
        cardElevated: .white.opacity(0.90),
        textPrimary: .black.opacity(0.85),
        textSecondary: .black.opacity(0.6),
        textTertiary: .black.opacity(0.45),
        textInverted: .white,
        accentPrimary: .black.opacity(0.75),
        accentSecondary: .gray.opacity(0.60),
        positiveGreen: .gray.opacity(0.70),
        negativeRed: .gray.opacity(0.70),
        warningOrange: .gray.opacity(0.70),
        chartLine: .black.opacity(0.65),
        chartArea: .gray.opacity(0.15),
        chartGrid: .gray.opacity(0.25),
        chartBarGradientStart: .black.opacity(0.60),
        chartBarGradientEnd: .gray.opacity(0.45),
        badgePremiumStart: .black.opacity(0.60),
        badgePremiumEnd: .black.opacity(0.80),
        premiumCardBackground: .black.opacity(0.06),
        recentContentCardBackground: .black.opacity(0.05),
        postsCardBackground: .black.opacity(0.05),
        decisionCardBackground: .black.opacity(0.06),
        badgeTrial: .black.opacity(0.60), badgeLocked: .gray.opacity(0.35),
        buttonPrimaryBg: .black.opacity(0.75),
        buttonDestructiveBg: .gray.opacity(0.70),
        buttonDisabledFg: .gray.opacity(0.35),
        divider: .gray.opacity(0.30),
        navigationBg: .gray.opacity(0.08), emptyStateIcon: .gray.opacity(0.50),
        displayName: "Mono Stone", liquidGlassEnabled: false, isDark: false
    )

    // MARK: - Nebula（星云紫 — 蓝 → 紫 → 粉夜景玻璃）

    static let purple = Theme(
        // 背景渐变（三色）：蓝 → 紫 → 粉（Liquid Glass Instagram 夜景）
        backgroundGradientColors: [
            .blue.opacity(0.25),
            .purple.opacity(0.25),
            .pink.opacity(0.15)
        ],
        // 保持系统背景作为底层
        backgroundPrimary: Color(.systemBackground),
        backgroundSecondary: Color(.secondarySystemBackground),
        backgroundGrouped: Color(.systemGroupedBackground),
        // 背景渐变辅助色：蓝紫冷色调
        backgroundGradientStart: .blue.opacity(0.25),
        backgroundGradientEnd: .pink.opacity(0.18),
        // 卡片使用半透明紫蓝玻璃效果
        cardSurface: .purple.opacity(0.10),
        cardElevated: .purple.opacity(0.18),
        // 文字
        textPrimary: .black.opacity(0.85),
        textSecondary: .black.opacity(0.6),
        textTertiary: .black.opacity(0.45),
        textInverted: .white,
        // 主色：紫作为品牌强调色
        accentPrimary: .purple,
        accentSecondary: .pink,
        // 状态色保持语义
        positiveGreen: .green,
        negativeRed: .red,
        warningOrange: .orange,
        // 图表颜色
        chartLine: .purple,
        chartArea: .purple.opacity(0.12),
        chartGrid: .gray.opacity(0.18),
        // 柱状图：蓝 → 粉
        chartBarGradientStart: .blue,
        chartBarGradientEnd: .pink,
        // Premium Badge：紫 → 粉
        badgePremiumStart: .purple,
        badgePremiumEnd: .pink,
        premiumCardBackground: .purple.opacity(0.10),
        recentContentCardBackground: .purple.opacity(0.07),
        postsCardBackground: .purple.opacity(0.07),
        decisionCardBackground: .pink.opacity(0.07),
        badgeTrial: .blue.opacity(0.8),
        badgeLocked: Color(.systemGray3),
        // Button
        buttonPrimaryBg: .purple,
        buttonDestructiveBg: .red,
        buttonDisabledFg: Color(.systemGray3),
        // 分割线
        divider: .gray.opacity(0.20),
        // Navigation
        navigationBg: Color(.systemBackground),
        // Empty State
        emptyStateIcon: .gray.opacity(0.5),
        displayName: "Nebula",
        liquidGlassEnabled: true,
        isDark: false
    )
    
    /// Instagram Dark — 深夜创作者风格
    /// 深黑空间 + 紫色光晕 + 品红高光，延续 Instagram 品牌同时适配 OLED / Liquid Glass
    static let instagramDark = Theme(
        // 背景渐变：极低饱和度的紫灰，不刺眼
        backgroundGradientColors: [
            Color(red: 0.08, green: 0.04, blue: 0.06),
            Color(red: 0.04, green: 0.02, blue: 0.07),
            .black
        ],
        backgroundPrimary: Color(red: 0.02, green: 0.01, blue: 0.03),
        backgroundSecondary: Color(red: 0.06, green: 0.03, blue: 0.07),
        backgroundGrouped: Color(red: 0.03, green: 0.02, blue: 0.05),
        backgroundGradientStart: Color(red: 0.10, green: 0.05, blue: 0.08),
        backgroundGradientEnd: .black,

        cardSurface: Color.white.opacity(0.06),
        cardElevated: Color.white.opacity(0.12),

        textPrimary: .white,
        textSecondary: Color.white.opacity(0.70),
        textTertiary: Color.white.opacity(0.45),
        textInverted: .black,

        // 核心：玫瑰金（比粉色更灰、更暖），搭配薰衣草灰
        accentPrimary: Color(red: 0.85, green: 0.55, blue: 0.50),   // 玫瑰金
        accentSecondary: Color(red: 0.50, green: 0.40, blue: 0.50), // 薰衣草灰

        positiveGreen: Color(red: 0.20, green: 0.80, blue: 0.55),
        negativeRed: Color(red: 0.95, green: 0.40, blue: 0.30),
        warningOrange: Color(red: 0.95, green: 0.60, blue: 0.20),

        chartLine: Color(red: 0.85, green: 0.55, blue: 0.50),
        chartArea: Color(red: 0.85, green: 0.55, blue: 0.50).opacity(0.12),
        chartGrid: Color.white.opacity(0.10),
        chartBarGradientStart: Color(red: 0.85, green: 0.55, blue: 0.50),
        chartBarGradientEnd: Color(red: 0.60, green: 0.35, blue: 0.45),

        badgePremiumStart: Color(red: 0.85, green: 0.55, blue: 0.50),
        badgePremiumEnd: Color(red: 0.70, green: 0.45, blue: 0.55),

        premiumCardBackground: .clear,
        recentContentCardBackground: .clear,
        postsCardBackground: .clear,
        decisionCardBackground: .clear,

        badgeTrial: Color(red: 0.85, green: 0.55, blue: 0.50),
        badgeLocked: Color.white.opacity(0.25),

        buttonPrimaryBg: Color(red: 0.85, green: 0.55, blue: 0.50),
        buttonDestructiveBg: Color(red: 0.95, green: 0.40, blue: 0.30),
        buttonDisabledFg: Color.white.opacity(0.25),

        divider: Color.white.opacity(0.10),
        navigationBg: Color(red: 0.02, green: 0.01, blue: 0.03),
        emptyStateIcon: Color.white.opacity(0.40),

        displayName: "Rose Noir",
        liquidGlassEnabled: true,
        isDark: true
    )

    // MARK: - Cream（羊皮纸白 — 纯色无渐变）

    /// 柔和温暖的米白 / 羊皮纸白主题：纯色背景（无渐变），卡片同色。
    /// 主背景 #FAF6E9 / 辅助浅褐 #E8DFD1
    static let cream = Theme(
        // 纯色背景：三个相同色 = LinearGradient 视觉上无渐变
        backgroundGradientColors: [
            Color(red: 250 / 255.0, green: 246 / 255.0, blue: 233 / 255.0),
            Color(red: 250 / 255.0, green: 246 / 255.0, blue: 233 / 255.0),
            Color(red: 250 / 255.0, green: 246 / 255.0, blue: 233 / 255.0)
        ],
        backgroundPrimary: Color(red: 250 / 255.0, green: 246 / 255.0, blue: 233 / 255.0),
        backgroundSecondary: Color(red: 250 / 255.0, green: 246 / 255.0, blue: 233 / 255.0),
        backgroundGrouped: Color(red: 250 / 255.0, green: 246 / 255.0, blue: 233 / 255.0),
        backgroundGradientStart: Color(red: 250 / 255.0, green: 246 / 255.0, blue: 233 / 255.0),
        backgroundGradientEnd: Color(red: 250 / 255.0, green: 246 / 255.0, blue: 233 / 255.0),
        // 卡片背景 = 主背景色（纯色平铺，非毛玻璃）
        cardSurface: Color(red: 250 / 255.0, green: 246 / 255.0, blue: 233 / 255.0),
        cardElevated: Color(red: 250 / 255.0, green: 246 / 255.0, blue: 233 / 255.0),
        // 文字：米白背景上使用柔和深棕灰
        textPrimary: Color(red: 0.30, green: 0.26, blue: 0.20),
        textSecondary: Color(red: 0.45, green: 0.40, blue: 0.32),
        textTertiary: Color(red: 0.58, green: 0.53, blue: 0.45),
        textInverted: .white,
        // 强调色：暖驼棕（与羊皮纸白协调）
        accentPrimary: Color(red: 0.69, green: 0.53, blue: 0.35),
        accentSecondary: Color(red: 232 / 255.0, green: 223 / 255.0, blue: 209 / 255.0),
        positiveGreen: Color(red: 0.45, green: 0.60, blue: 0.35),
        negativeRed: Color(red: 0.75, green: 0.35, blue: 0.30),
        warningOrange: Color(red: 0.80, green: 0.55, blue: 0.25),
        chartLine: Color(red: 0.69, green: 0.53, blue: 0.35),
        chartArea: Color(red: 0.69, green: 0.53, blue: 0.35).opacity(0.12),
        chartGrid: Color(red: 0.80, green: 0.76, blue: 0.68),
        chartBarGradientStart: Color(red: 0.69, green: 0.53, blue: 0.35),
        chartBarGradientEnd: Color(red: 0.80, green: 0.65, blue: 0.45),
        badgePremiumStart: Color(red: 0.69, green: 0.53, blue: 0.35),
        badgePremiumEnd: Color(red: 0.80, green: 0.65, blue: 0.45),
        premiumCardBackground: Color(red: 0.69, green: 0.53, blue: 0.35).opacity(0.12),
        recentContentCardBackground: Color(red: 0.69, green: 0.53, blue: 0.35).opacity(0.08),
        postsCardBackground: Color(red: 0.69, green: 0.53, blue: 0.35).opacity(0.08),
        decisionCardBackground: Color(red: 0.80, green: 0.65, blue: 0.45).opacity(0.08),
        badgeTrial: Color(red: 0.69, green: 0.53, blue: 0.35),
        badgeLocked: Color(red: 0.80, green: 0.76, blue: 0.68),
        buttonPrimaryBg: Color(red: 0.69, green: 0.53, blue: 0.35),
        buttonDestructiveBg: Color(red: 0.75, green: 0.35, blue: 0.30),
        buttonDisabledFg: Color(red: 0.80, green: 0.76, blue: 0.68),
        divider: Color(red: 0.84, green: 0.80, blue: 0.72),
        navigationBg: Color(red: 250 / 255.0, green: 246 / 255.0, blue: 233 / 255.0),
        emptyStateIcon: Color(red: 0.58, green: 0.53, blue: 0.45),
        displayName: "Cream",
        liquidGlassEnabled: false,   // 纯色平铺（卡片 = 背景色）
        isDark: false
    )
    // MARK: - Pure Black（纯黑背景 + 灰黑卡片 — 无任何额外风格）

    /// 极简纯黑主题：纯黑背景 + 灰黑卡片，无渐变、无品牌色、无玻璃特效。
    /// 强调/图表/徽章全部中性（白/灰）；绿红橙仅保留状态语义（授权/删除/警告）。
    static let pureBlack = Theme(
        // 背景：纯黑（无渐变 — 三色全黑）
        backgroundGradientColors: [.black, .black, .black],
        backgroundPrimary: .black,
        backgroundSecondary: .black,
        backgroundGrouped: .black,
        backgroundGradientStart: .black,
        backgroundGradientEnd: .black,
        // 卡片：灰黑（比纯黑背景亮一档，形成区分度）
        cardSurface: Color(UIColor.secondarySystemGroupedBackground),
        cardElevated: Color(UIColor.secondarySystemGroupedBackground),
        textPrimary: .white,
        textSecondary: .white.opacity(0.65),
        textTertiary: .white.opacity(0.45),
        textInverted: .black,
        // 强调：中性白/灰（无品牌色）
        accentPrimary: .white,
        accentSecondary: .gray,
        // 语义色保留 — 状态含义必须可辨（授权绿 / 删除红 / 警告橙）
        positiveGreen: .green,
        negativeRed: .red,
        warningOrange: .orange,
        chartLine: .white,
        chartArea: .white.opacity(0.12),
        chartGrid: .gray.opacity(0.30),
        chartBarGradientStart: .white,
        chartBarGradientEnd: .gray,
        badgePremiumStart: .white,
        badgePremiumEnd: .gray,
        // 卡片填充：灰黑纯色（Premium / Recent / Posts / 决策卡片同色 — 无品牌色分层）
        premiumCardBackground: Color(UIColor.secondarySystemGroupedBackground),
        recentContentCardBackground: Color(UIColor.secondarySystemGroupedBackground),
        postsCardBackground: Color(UIColor.secondarySystemGroupedBackground),
        decisionCardBackground: Color(UIColor.secondarySystemGroupedBackground),
        badgeTrial: .white,
        badgeLocked: .gray.opacity(0.40),
        buttonPrimaryBg: .white,
        buttonDestructiveBg: .red,
        buttonDisabledFg: .gray.opacity(0.40),
        divider: .gray.opacity(0.25),
        navigationBg: .black,
        emptyStateIcon: .gray.opacity(0.5),
        displayName: "Pure Black",
        liquidGlassEnabled: false,   // 纯色平铺 — 无毛玻璃，仅黑底 + 灰黑卡片
        isDark: true
    )
}

// MARK: - AppTheme

/// 主题枚举 — 9 套可选主题，提供 theme / displayName 计算属性
enum AppTheme: String, CaseIterable {
    case appleNative, instagram, appleDark, forest, monoStone, purple, instagramDark, cream, pureBlack

    /// 将枚举值映射到对应的 Theme 实例
    var theme: Theme {
        switch self {
        case .appleNative: .appleNative
        case .instagram:   .instagram
        case .appleDark:   .appleDark
        case .forest:      .forest
        case .monoStone:   .monoStone
        case .purple:      .purple
        case .instagramDark: .instagramDark
        case .cream:         .cream
        case .pureBlack:     .pureBlack
        }
    }

    /// 本地化后的主题展示名称
    var displayName: String {
        switch self {
        case .appleNative: loc(L10n.Settings.appleNative)
        case .instagram:   loc(L10n.Settings.instagram)
        case .appleDark:   loc(L10n.Settings.appleDark)
        case .forest:      loc(L10n.Settings.forest)
        case .monoStone:   loc(L10n.Settings.monoStone)
        case .purple:      loc(L10n.Settings.purple)
        case .instagramDark: loc(L10n.Settings.instagramDark)
        case .cream:         loc(L10n.Settings.cream)
        case .pureBlack:     loc(L10n.Settings.pureBlack)
        }
    }
}

// MARK: - Environment

/// 自定义 Environment key：注入当前 Theme
private struct ThemeKey: EnvironmentKey { static let defaultValue: Theme = .appleNative }
/// 自定义 Environment key：控制 Liquid Glass 效果
private struct LiquidGlassKey: EnvironmentKey { static let defaultValue: Bool = true }

extension EnvironmentValues {
    /// 从环境读取当前主题
    var theme: Theme { get { self[ThemeKey.self] } set { self[ThemeKey.self] = newValue } }
    /// 从环境读取 Liquid Glass 开关状态
    var useLiquidGlass: Bool { get { self[LiquidGlassKey.self] } set { self[LiquidGlassKey.self] = newValue } }
}

// MARK: - Modifiers

/// ViewModifier：将 Theme 注入 SwiftUI 环境
struct ThemeModifier: ViewModifier {
    let theme: Theme
    func body(content: Content) -> some View {
        content.environment(\.theme, theme).environment(\.useLiquidGlass, theme.liquidGlassEnabled)
    }
}

/// ViewModifier：毛玻璃卡片样式（Material + 半透明色板 + 分割线 + 阴影）
struct LiquidGlassCard: ViewModifier {
    @Environment(\.theme) private var theme
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
                    RoundedRectangle(cornerRadius: 16).fill(theme.cardSurface)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(theme.divider, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(theme.isDark ? 0.10 : 0.05), radius: 8, y: 2)
    }
}

extension View {
    /// 为视图子树注入指定主题
    func withTheme(_ theme: Theme) -> some View { modifier(ThemeModifier(theme: theme)) }
    /// 应用 Liquid Glass 毛玻璃卡片样式
    func liquidGlassCard() -> some View { modifier(LiquidGlassCard()) }
}

// MARK: - Theme Sync Modifier（主题同步状态机客户端）

/// 主题同步修饰符 — 从 AppState 实时注入当前 theme + tint + colorScheme。
/// 解决 sheet 内容环境快照问题（呈现时捕获、主树更新不传播）：
/// 1) 直接观察 appState.currentTheme（@Observable）→ 变化即重新注入
/// 2) 监听 .themeChanged 通知强制重绘（environment 传播边界的双保险）
/// 3) 显式绑定 \.colorScheme — 让 .secondary/.primary/系统控件随主题 isDark 同步
///    （仅改自定义颜色不会驱动 SwiftUI 系统色，这是深色模式不同步的根源）
struct ThemeSyncModifier: ViewModifier {
    @Environment(AppState.self) private var appState
    @State private var syncTick = 0

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .themeChanged)) { _ in
                syncTick += 1   // 强制 body 重算 → 用最新 theme 重新注入
            }
            .withTheme(appState.currentTheme.theme)
            .tint(appState.currentTheme.theme.accentPrimary)
            .environment(\.colorScheme, appState.currentTheme.theme.isDark ? .dark : .light)
    }
}

extension View {
    /// 应用主题同步 — sheet / 弹窗内容必须使用，切换主题时实时跟随 AppState
    func themeSynced() -> some View { modifier(ThemeSyncModifier()) }
}
