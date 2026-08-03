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

    // MARK: - Instagram（日落微醺光影 → 高级透亮浅色）
    static let instagram: Theme = {
        // 1. 提取 Instagram 品牌的低饱和高级配色
        let instaSunsetOrange = Color(red: 250/255, green: 130/255, blue: 49/255)  // 暖杏日落橙
        let instaSunsetPink   = Color(red: 224/255, green: 86/255,  blue: 136/255) // 暮光软莓粉
        let instaSunsetPurple = Color(red: 168/255, green: 85/255,  blue: 247/255) // 梦幻微醺紫

        return Theme(
            // 背景渐变：大幅降低不透明度（5%~10%），打造光晕呼吸感而非大块死色
            backgroundGradientColors: [
                instaSunsetOrange.opacity(0.10),
                instaSunsetPink.opacity(0.08),
                instaSunsetPurple.opacity(0.06)
            ],
            backgroundPrimary: Color(.systemBackground),
            backgroundSecondary: Color(.secondarySystemBackground),
            backgroundGrouped: Color(.systemGroupedBackground),
            
            backgroundGradientStart: instaSunsetOrange.opacity(0.10),
            backgroundGradientEnd: instaSunsetPurple.opacity(0.06),
            
            // 关键改动：卡片表面切忌直接加浓橙色，改用极淡的粉白/半透明纯白，提升高级“玻璃/纸质”质感
            cardSurface: Color.white.opacity(0.65),
            cardElevated: Color.white.opacity(0.85),
            
            textPrimary: .black.opacity(0.85),
            textSecondary: .black.opacity(0.6),
            textTertiary: .black.opacity(0.45),
            textInverted: .white,
            
            // 主强调色使用柔和的 Instagram 品牌主色（橙/粉）
            accentPrimary: instaSunsetPink,
            accentSecondary: instaSunsetOrange,
            
            positiveGreen: .green,
            negativeRed: .red,
            warningOrange: instaSunsetOrange,
            
            // 图表：使用暮光粉作为主线，图表填充极淡
            chartLine: instaSunsetPink,
            chartArea: instaSunsetPink.opacity(0.08),
            chartGrid: .gray.opacity(0.12),
            
            // 图表柱状图 & 徽章：经典日落渐变（橙 → 粉）
            chartBarGradientStart: instaSunsetOrange,
            chartBarGradientEnd: instaSunsetPink,
            badgePremiumStart: instaSunsetOrange,
            badgePremiumEnd: instaSunsetPink,
            badgeTrial: instaSunsetOrange,
            badgeLocked: Color(.systemGray3),
            
            // 按钮：主按钮采用充满活力的品牌粉色
            buttonPrimaryBg: instaSunsetPink,
            buttonDestructiveBg: .red,
            buttonDisabledFg: Color(.systemGray3),
            
            divider: .gray.opacity(0.12),
            navigationBg: Color(.systemBackground),
            emptyStateIcon: .gray.opacity(0.4),
            
            displayName: "Instagram",
            liquidGlassEnabled: true,
            isDark: false
        )
    }()
    
    // MARK: - Apple Dark（深黑 → 暗蓝渐变）
    static let appleDark = Theme(
        // 背景渐变（三色）：深靛蓝 → 暗蓝 → 近黑
        backgroundGradientColors: [
            .indigo.opacity(0.30),
            .blue.opacity(0.15),
            .black
        ],
        backgroundPrimary: .black,
        backgroundSecondary: .gray.opacity(0.12),
        backgroundGrouped: .black,
        backgroundGradientStart: .indigo.opacity(0.30),
        backgroundGradientEnd: .black,
        cardSurface: .gray.opacity(0.15),
        cardElevated: .gray.opacity(0.22),
        textPrimary: .white,
        textSecondary: .white.opacity(0.65),
        textTertiary: .white.opacity(0.45),
        textInverted: .black,
        accentPrimary: .blue,
        accentSecondary: .cyan,
        positiveGreen: .green,
        negativeRed: .red,
        warningOrange: .orange,
        chartLine: .blue,
        chartArea: .blue.opacity(0.15),
        chartGrid: .gray.opacity(0.25),
        chartBarGradientStart: .blue,
        chartBarGradientEnd: .indigo,
        badgePremiumStart: .orange,
        badgePremiumEnd: .pink,
        badgeTrial: .orange,
        badgeLocked: .gray.opacity(0.35),
        buttonPrimaryBg: .blue,
        buttonDestructiveBg: .red,
        buttonDisabledFg: .gray.opacity(0.35),
        divider: .gray.opacity(0.25),
        navigationBg: .black,
        emptyStateIcon: .gray.opacity(0.5),
        displayName: "Apple Dark", liquidGlassEnabled: true, isDark: true
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
        badgeTrial: .mint, badgeLocked: .gray.opacity(0.30),
        buttonPrimaryBg: .green,
        buttonDestructiveBg: .red,
        buttonDisabledFg: .gray.opacity(0.30),
        divider: .gray.opacity(0.15),
        navigationBg: .mint.opacity(0.15), emptyStateIcon: .gray.opacity(0.40),
        displayName: "Forest", liquidGlassEnabled: true, isDark: false
    )

    // MARK: - Rose Gold（暖玫瑰粉 → 柔白）

    // MARK: - Rose Gold（暖玫瑰粉 → 柔白）

    /// 精确玫瑰粉 #E8A39C — 重构后所有玫瑰金相关颜色统一使用该精准色
    private static let preciseRosePink = Color(red: 0xE8 / 255.0, green: 0xA3 / 255.0, blue: 0x9C / 255.0)

    static let roseGold = Theme(
        // 背景渐变（三色）：柔和的玫瑰粉 → 更淡的藕粉 → 纯白
        backgroundGradientColors: [
            // 降低了起始颜色的不透明度，使过渡更柔和
            preciseRosePink.opacity(0.18),
            preciseRosePink.opacity(0.08),
            .white
        ],
        backgroundPrimary: .white,
        // 次要和成组背景使用极低的不透明度，仅提供最微妙的色调区别
        backgroundSecondary: preciseRosePink.opacity(0.04),
        backgroundGrouped: preciseRosePink.opacity(0.02),
        backgroundGradientStart: preciseRosePink.opacity(0.18),
        backgroundGradientEnd: .white,
        // 卡片表面维持纯白毛玻璃（原设置意图更强）
        cardSurface: .white.opacity(0.50),
        cardElevated: .white.opacity(0.75),
        textPrimary: .black.opacity(0.85),
        textSecondary: .black.opacity(0.6),
        textTertiary: .black.opacity(0.45), textInverted: .white,
        // 主强调色和图表线使用精准色
        accentPrimary: preciseRosePink,
        accentSecondary: .purple, // 保持紫色作为次要强调，与暖粉色形成对比
        positiveGreen: .green,
        negativeRed: .red,
        warningOrange: .orange,
        chartLine: preciseRosePink,
        // 图表区域使用较低不透明度的精准色
        chartArea: preciseRosePink.opacity(0.08),
        chartGrid: .gray.opacity(0.15),
        // 图表和徽章渐变维持粉到紫的过渡，但粉色用精准色
        chartBarGradientStart: preciseRosePink,
        chartBarGradientEnd: .purple,
        badgePremiumStart: preciseRosePink,
        badgePremiumEnd: .purple,
        badgeTrial: preciseRosePink,
        badgeLocked: .gray.opacity(0.35),
        // 按钮使用精准色
        buttonPrimaryBg: preciseRosePink,
        buttonDestructiveBg: .red,
        buttonDisabledFg: .gray.opacity(0.35),
        divider: .gray.opacity(0.15),
        // 导航栏背景降低不透明度
        navigationBg: preciseRosePink.opacity(0.04),
        emptyStateIcon: .gray.opacity(0.45),
        displayName: "Rose Gold",
        liquidGlassEnabled: true, // 启用此效果通常需要背景有渐变或透明度，新的设置能很好地配合
        isDark: false
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

    // MARK: - Obsidian Amethyst (黑曜紫晶 — 液态玻璃高级深色)
    /// Obsidian Amethyst — 极简高级创作者风格
    /// 摒弃高饱和原色，采用微调黑曜石底色与低调的粉紫光晕，专为 Liquid Glass & OLED 优化
    static let instagramDark = Theme(
        // 背景渐变（三色）：纯粹深黑 → 深微靛蓝 → 幽暗红紫（降低饱和度与亮度，防止夺目）
        backgroundGradientColors: [
            Color(red: 0.11, green: 0.05, blue: 0.12),
            Color(red: 0.06, green: 0.04, blue: 0.11),
            Color(red: 0.01, green: 0.01, blue: 0.03)
        ],
        // 深色系统背景：极致纯黑搭配微冷调层次
        backgroundPrimary: Color(red: 0.02, green: 0.02, blue: 0.03),
        backgroundSecondary: Color(red: 0.05, green: 0.05, blue: 0.07),
        backgroundGrouped: Color(red: 0.08, green: 0.08, blue: 0.11),
        
        // 背景光源：柔和弥散光（弱化不透明度，提升透光感）
        backgroundGradientStart: Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.18), // 霓虹柔紫
        backgroundGradientEnd: Color(red: 0.95, green: 0.35, blue: 0.65).opacity(0.12),   // 柔粉桃红
        
        // Liquid Glass 卡片：高透光 + 微弱高光
        cardSurface: Color.white.opacity(0.04),
        cardElevated: Color.white.opacity(0.08),
        
        // Typography：采用微冷的纯白度，减少视觉疲劳
        textPrimary: Color(red: 0.96, green: 0.96, blue: 0.98),
        textSecondary: Color.white.opacity(0.55),
        textTertiary: Color.white.opacity(0.35),
        textInverted: Color(red: 0.05, green: 0.05, blue: 0.08),
        
        // Obsidian Accent：自定义的高级感 Accent（精准 RGB 微调）
        accentPrimary: Color(red: 0.68, green: 0.45, blue: 0.98),   // 柔紫 (Soft Violet)
        accentSecondary: Color(red: 0.95, green: 0.42, blue: 0.62), // 霓桃粉 (Neon Peach)
        
        // 状态颜色：高级灰度调和色（降低原色刺眼感）
        positiveGreen: Color(red: 0.20, green: 0.78, blue: 0.55),
        negativeRed: Color(red: 0.92, green: 0.34, blue: 0.42),
        warningOrange: Color(red: 0.95, green: 0.60, blue: 0.28),
        
        // Charts：精致渐变与清亮网格
        chartLine: Color(red: 0.95, green: 0.42, blue: 0.62),
        chartArea: Color(red: 0.95, green: 0.42, blue: 0.62).opacity(0.10),
        chartGrid: Color.white.opacity(0.06),
        
        // 数据柱状图：柔紫 → 霓桃粉
        chartBarGradientStart: Color(red: 0.68, green: 0.45, blue: 0.98),
        chartBarGradientEnd: Color(red: 0.95, green: 0.42, blue: 0.62),
        
        // Premium Badge
        badgePremiumStart: Color(red: 0.68, green: 0.45, blue: 0.98),
        badgePremiumEnd: Color(red: 0.95, green: 0.42, blue: 0.62),
        badgeTrial: Color(red: 0.68, green: 0.45, blue: 0.98).opacity(0.7),
        badgeLocked: Color.white.opacity(0.18),
        
        // Buttons：渐变高光按钮替代纯红/纯粉
        buttonPrimaryBg: Color(red: 0.95, green: 0.42, blue: 0.62),
        buttonDestructiveBg: Color(red: 0.85, green: 0.25, blue: 0.35),
        buttonDisabledFg: Color.white.opacity(0.20),
        
        // Divider：更细致的暗色割线
        divider: Color.white.opacity(0.08),
        
        // Navigation
        navigationBg: Color(red: 0.02, green: 0.02, blue: 0.03).opacity(0.85),
        
        // Empty State
        emptyStateIcon: Color.white.opacity(0.35),
        displayName: "Instagram Dark",
        liquidGlassEnabled: true,
        isDark: true
    )
}

// MARK: - AppTheme

/// 主题枚举 — 6 套可选主题，提供 theme / displayName 计算属性
enum AppTheme: String, CaseIterable {
    case appleNative, instagram, appleDark, forest, roseGold, monoStone, purple, instagramDark

    /// 将枚举值映射到对应的 Theme 实例
    var theme: Theme {
        switch self {
        case .appleNative: .appleNative
        case .instagram:   .instagram
        case .appleDark:   .appleDark
        case .forest:      .forest
        case .roseGold:    .roseGold
        case .monoStone:   .monoStone
        case .purple:      .purple
        case .instagramDark: .instagramDark
        }
    }

    /// 本地化后的主题展示名称
    var displayName: String {
        switch self {
        case .appleNative: loc(L10n.Settings.appleNative)
        case .instagram:   loc(L10n.Settings.instagram)
        case .appleDark:   loc(L10n.Settings.appleDark)
        case .forest:      loc(L10n.Settings.forest)
        case .roseGold:    loc(L10n.Settings.roseGold)
        case .monoStone:   loc(L10n.Settings.monoStone)
        case .purple:      loc(L10n.Settings.purple)
        case .instagramDark: loc(L10n.Settings.instagramDark)
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
