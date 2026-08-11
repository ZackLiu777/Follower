//
//  PredictionTrendChart.swift
//  Follower
//
//  Lambda: 粉丝预测区间时序图（Swift Charts）。
//  历史实线 + 未来中位数虚线 + 50/80/95% 三层渐变区间带 + "今天"垂直分界线。
//  预测段纵轴 = baseFollowers + 逐日累计增长分位数（与 predictedFollowers 语义一致）。
//
//  图层声明顺序（先声明的在下层）：
//    95% 带（最浅）→ 80% 带 → 50% 带（最深）→ 中位数虚线 → 今天线 → 历史实线
//

import SwiftUI
import Charts

/// 粉丝预测区间时序图 — 历史 + 预测带（compact 用于卡片，全尺寸用于详情页）
struct PredictionTrendChart: View {
    @Environment(\.theme) private var theme

    /// 历史粉丝数（升序，带日期）
    let historical: [(Date, Double)]
    /// 预测起点日期（= 最后历史点，绘制"今天"分界线）
    let forecastStart: Date
    /// 当前粉丝数 — 预测段 y = base + 累计增长
    let baseFollowers: Double
    /// 逐日累计增长 2.5% 分位（31 点，含起点 0）— 95% 带
    let dailyLower: [Double]
    /// 逐日累计增长 10% 分位 — 80% 带
    let dailyQ10: [Double]
    /// 逐日累计增长 25% 分位 — 50% 带
    let dailyQ25: [Double]
    /// 逐日累计增长中位数
    let dailyMedian: [Double]
    /// 逐日累计增长 75% 分位 — 50% 带上界
    let dailyQ75: [Double]
    /// 逐日累计增长 90% 分位 — 80% 带上界
    let dailyQ90: [Double]
    /// 逐日累计增长 97.5% 分位 — 95% 带上界
    let dailyUpper: [Double]

    var compact: Bool = false

    /// 预测段日期序列（forecastStart + 0...n−1 天）
    private var forecastDates: [Date] {
        let cal = Calendar.current
        return dailyMedian.indices.map { cal.date(byAdding: .day, value: $0, to: forecastStart) ?? forecastStart }
    }

    var body: some View {
        Group {
            if compact {
                chartContent
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
            } else {
                chartContent
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(theme.divider.opacity(0.5))
                            AxisValueLabel().foregroundStyle(theme.textTertiary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(theme.divider.opacity(0.5))
                            AxisValueLabel().foregroundStyle(theme.textTertiary)
                        }
                    }
            }
        }
    }

    /// 图表内容（含全部图层）
    private var chartContent: some View {
        Chart {
            // ── 三层预测区间带（95% 最浅 → 50% 最深）──
            ForEach(forecastDates.indices, id: \.self) { i in
                AreaMark(
                    x: .value("Date", forecastDates[i]),
                    yStart: .value("low95", baseFollowers + dailyLower[i]),
                    yEnd: .value("high95", baseFollowers + dailyUpper[i])
                )
                .foregroundStyle(theme.chartArea.opacity(0.5))   // 叠加后 ~0.05-0.06
                .interpolationMethod(.catmullRom)
            }
            ForEach(forecastDates.indices, id: \.self) { i in
                AreaMark(
                    x: .value("Date", forecastDates[i]),
                    yStart: .value("low80", baseFollowers + dailyQ10[i]),
                    yEnd: .value("high80", baseFollowers + dailyQ90[i])
                )
                .foregroundStyle(theme.chartArea.opacity(0.9))   // ~0.09-0.11
                .interpolationMethod(.catmullRom)
            }
            ForEach(forecastDates.indices, id: \.self) { i in
                AreaMark(
                    x: .value("Date", forecastDates[i]),
                    yStart: .value("low50", baseFollowers + dailyQ25[i]),
                    yEnd: .value("high50", baseFollowers + dailyQ75[i])
                )
                .foregroundStyle(theme.chartArea.opacity(1.0))   // ~0.10-0.12 基础值
                .interpolationMethod(.catmullRom)
            }

            // ── 预测中位数虚线 ──
            ForEach(forecastDates.indices, id: \.self) { i in
                LineMark(
                    x: .value("Date", forecastDates[i]),
                    y: .value("Median", baseFollowers + dailyMedian[i])
                )
                .foregroundStyle(theme.chartLine)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .interpolationMethod(.catmullRom)
            }

            // ── "今天"分界线 ──
            RuleMark(x: .value("Today", forecastStart))
                .foregroundStyle(theme.textTertiary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [2, 2]))

            // ── 历史实线（最上层）──
            ForEach(historical, id: \.0) { date, value in
                LineMark(
                    x: .value("Date", date),
                    y: .value("Followers", value)
                )
                .foregroundStyle(theme.chartLine)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
//  MARK: - Preview
// ═══════════════════════════════════════════════════════

/// 生成与真实使用一致的示例数据（确定性公式，无随机 → 多次预览结果稳定）。
/// 形态：90 天历史缓慢增长（~8000 → ~8460）+ 30 天预测累计增长分位（中位 ~171）。
private func samplePredictionChartData() -> (
    historical: [(Date, Double)], forecastStart: Date, base: Double,
    lower: [Double], q10: [Double], q25: [Double], median: [Double],
    q75: [Double], q90: [Double], upper: [Double]
) {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())

    // 历史：90 天，日增 ~5 的确定性波动序列
    let historical: [(Date, Double)] = (0..<90).map { i in
        let date = cal.date(byAdding: .day, value: -(89 - i), to: today)!
        return (date, 8000.0 + 5.0 * Double(i) + Double((i * 7) % 11))
    }
    let base = historical.last!.1

    // 预测：逐日累计增长中位（每天 ~4.2 略加速），带宽分层（50/80/95%）
    let median = (0...30).map { 4.2 * Double($0) + 0.05 * Double($0 * $0) }
    let q25 = median.map { $0 - 12 }
    let q75 = median.map { $0 + 12 }
    let q10 = median.map { $0 - 30 }
    let q90 = median.map { $0 + 30 }
    let lower = median.map { $0 - 70 }
    let upper = median.map { $0 + 70 }
    return (historical, today, base, lower, q10, q25, median, q75, q90, upper)
}

/// 全尺寸（详情页）：Apple Native 主题
#Preview("Full — Apple Native") {
    let d = samplePredictionChartData()
    PredictionTrendChart(
        historical: d.historical,
        forecastStart: d.forecastStart,
        baseFollowers: d.base,
        dailyLower: d.lower,
        dailyQ10: d.q10,
        dailyQ25: d.q25,
        dailyMedian: d.median,
        dailyQ75: d.q75,
        dailyQ90: d.q90,
        dailyUpper: d.upper
    )
    .frame(height: 240)
    .padding()
}

/// 全尺寸（详情页）：Instagram 主题 — 双主题视觉对比
#Preview("Full — Instagram") {
    let d = samplePredictionChartData()
    PredictionTrendChart(
        historical: d.historical,
        forecastStart: d.forecastStart,
        baseFollowers: d.base,
        dailyLower: d.lower,
        dailyQ10: d.q10,
        dailyQ25: d.q25,
        dailyMedian: d.median,
        dailyQ75: d.q75,
        dailyQ90: d.q90,
        dailyUpper: d.upper
    )
    .frame(height: 240)
    .padding()
    .environment(\.theme, .instagram)
}

/// compact（Dashboard 主卡片内嵌）：隐藏双轴
#Preview("Compact Card") {
    let d = samplePredictionChartData()
    PredictionTrendChart(
        historical: d.historical,
        forecastStart: d.forecastStart,
        baseFollowers: d.base,
        dailyLower: d.lower,
        dailyQ10: d.q10,
        dailyQ25: d.q25,
        dailyMedian: d.median,
        dailyQ75: d.q75,
        dailyQ90: d.q90,
        dailyUpper: d.upper,
        compact: true
    )
    .frame(height: 110)
    .padding()
    .background(.regularMaterial)
}
