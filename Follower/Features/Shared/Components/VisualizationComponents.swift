//
//  VisualizationComponents.swift
//  Follower
//
//  Lambda-3: Premium 详情页共享可视化组件 —
//  环形仪表（ScoreGaugeView）、分段量表（SegmentedScaleView）、双条对比（DualBarCompareView）。
//  统一 0-100 分数档位标准（ScoreTier），消除各页面阈值不一致。
//  组件内只依赖 theme token 与输入数据，不含业务逻辑。
//

import SwiftUI

// MARK: - ScoreTier（统一评分档位）

/// 0-100 分数档位 — 全局统一标准：≥80 优 / ≥60 良 / ≥40 中 / <40 差
enum ScoreTier: Int {
    case poor = 0, fair, good, excellent

    /// 根据分数返回档位（确定性纯函数，便于测试）
    static func tier(for score: Double) -> ScoreTier {
        switch score {
        case 80...: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        default: return .poor
        }
    }
}

// MARK: - ScoreGaugeView（环形仪表）

/// 环形仪表 — 0-100 分数可视化：渐变环 + 中心分数
/// 色带：≥80 绿 / ≥60 主色 / ≥40 橙 / <40 红（由 ScoreTier.tier 驱动）
struct ScoreGaugeView: View {
    @Environment(\.theme) private var theme

    /// 分数（0-100）
    let score: Double
    /// 环尺寸（详情 Hero 用 140，行内小号用 40）
    var size: CGFloat = 120
    /// 中心文字（默认纯分数）
    var centerText: String? = nil

    private var progress: Double { min(max(score, 0), 100) / 100 }

    private var tierColor: Color {
        switch ScoreTier.tier(for: score) {
        case .excellent: return theme.positiveGreen
        case .good: return theme.accentPrimary
        case .fair: return theme.warningOrange
        case .poor: return theme.negativeRed
        }
    }

    /// 渐变环 + 中心分数 UI
    var body: some View {
        ZStack {
            // 底环
            Circle()
                .stroke(theme.divider, lineWidth: max(size * 0.08, 3))
            // 进度环（渐变：主色 → 主色淡化）
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: [tierColor, tierColor.opacity(0.55)], center: .center),
                    style: StrokeStyle(lineWidth: max(size * 0.08, 3), lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            // 中心分数
            Text(centerText ?? String(format: "%.0f", score))
                .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                .foregroundColor(tierColor)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - SegmentedScaleView（分段量表）

/// 分段量表 — 4 档等级可视条（None/Low/Medium/High 或自定义档位）：
/// 当前档位及以下点亮当前档颜色，其余置灰。等级大小一眼可辨。
struct SegmentedScaleView: View {
    @Environment(\.theme) private var theme

    /// 当前档位（0 起）
    let level: Int
    /// 档位点亮颜色
    let levelColor: Color
    /// 档位文字（可选，显示在条右侧）
    var levelLabel: String? = nil
    /// 段数（默认 4 档）
    var segments: Int = 4

    /// 分段量表 UI：N 段胶囊条 + 可选档位文字
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<segments, id: \.self) { index in
                Capsule()
                    .fill(index <= level ? levelColor : theme.divider)
                    .frame(height: 8)
            }
            if let levelLabel {
                Text(levelLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - DualBarCompareView（双条对比）

/// 双条对比 — 两个数值的横向比例条（前周期 vs 当前周期 / 你 vs 同类均值）。
/// 两条按各自占二者最大值的比例绘制，相对大小一目了然。
/// 自带卡片外观（cardSurface + 圆角），直接作为整卡使用。
struct DualBarCompareView: View {
    @Environment(\.theme) private var theme

    /// 卡片标题
    let title: String
    /// 左侧条：标签 + 数值 + 颜色
    let leftLabel: String
    let leftValue: Double
    let leftColor: Color
    /// 右侧条：标签 + 数值 + 颜色
    let rightLabel: String
    let rightValue: Double
    let rightColor: Color

    private var maxValue: Double { max(leftValue, rightValue, 1) }

    /// 双条对比卡片 UI
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            barRow(label: leftLabel, value: leftValue, color: leftColor)
            barRow(label: rightLabel, value: rightValue, color: rightColor)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    /// 单条：标签行 + 比例条
    private func barRow(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(theme.divider)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * min(value / maxValue, 1))
                }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - HeatmapGrid（GitHub 贡献砖格）

/// GitHub 贡献砖格风格热力图 — 行 = 星期、列 = 小时：
/// - 5 档色阶（0 = 灰底，1-4 = 主题色递进），与 GitHub 贡献图同构
/// - 顶部小时刻度（每 3 格标注）+ 左侧星期标签
/// - 点击单元格显示详情条（星期 时:00 · 密度 %）
struct HeatmapGrid: View {
    @Environment(\.theme) private var theme

    /// 7 行 × 24 列密度矩阵（0.0-1.0），行顺序由调用方决定（Mon-first / Sun-first）
    let rows: [[Double]]
    /// 行标签（7 个，与 rows 顺序一致，本地化后传入）
    let dayLabels: [String]

    @State private var selectedRow: Int?
    @State private var selectedCol: Int?

    private let labelWidth: CGFloat = 30
    private let spacing: CGFloat = 3

    /// GitHub 风格 5 档色阶映射（确定性纯函数，便于测试）：
    /// 0 → 无数据（灰）；(0, 0.25) → 1 档；[0.25, 0.5) → 2 档；[0.5, 0.75) → 3 档；≥0.75 → 4 档
    static func tier(for density: Double) -> Int {
        switch density {
        case 0: return 0
        case ..<0.25: return 1
        case ..<0.5: return 2
        case ..<0.75: return 3
        default: return 4
        }
    }

    /// 档位 → 颜色：0 灰（divider），1-4 主题色不透明度递进
    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 0: return theme.divider
        case 1: return theme.accentPrimary.opacity(0.15)
        case 2: return theme.accentPrimary.opacity(0.35)
        case 3: return theme.accentPrimary.opacity(0.60)
        default: return theme.accentPrimary.opacity(0.90)
        }
    }

    /// GitHub 砖格 UI：顶部小时刻度 + 7 行砖格 + 选中详情条。
    /// 用 HStack + aspectRatio(1) 自适应布局（不使用 GeometryReader）：
    /// 每行 24 格由 HStack 均分宽度、正方形高度由宽度推导，VStack 自然撑开
    /// 全部 7 行——避免 GeometryReader 初始宽度未定时 cell 被压缩导致
    /// 网格只渲染部分行的问题。
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            // 顶部小时刻度行（每 3 格标注），列宽与砖格对齐
            HStack(spacing: spacing) {
                Color.clear.frame(width: labelWidth, height: 12)
                ForEach(0..<24, id: \.self) { hour in
                    Text(hour % 3 == 0 ? "\(hour)" : "")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            // 7 行砖格
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: spacing) {
                    Text(dayLabels[row])
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .frame(width: labelWidth, alignment: .leading)
                        .foregroundColor(.secondary)
                    ForEach(0..<24, id: \.self) { col in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(tierColor(Self.tier(for: rows[row][col])))
                            // 长条矩形（宽:高 = 1.6:1），与横向小时刻度呼应
                            .aspectRatio(1.6, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .strokeBorder(
                                        (selectedRow == row && selectedCol == col) ? theme.accentPrimary : .clear,
                                        lineWidth: 1
                                    )
                            )
                            .onTapGesture {
                                selectedRow = row
                                selectedCol = col
                            }
                    }
                }
            }
            // 选中详情条（GitHub tooltip 的静态版，流式追加不遮挡）
            if let row = selectedRow, let col = selectedCol {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tierColor(Self.tier(for: rows[row][col])))
                        .frame(width: 10, height: 10)
                    Text("\(dayLabels[row]) \(String(format: "%02d:00", col)) · \(String(format: "%.0f%%", rows[row][col] * 100))")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
        }
    }
}
