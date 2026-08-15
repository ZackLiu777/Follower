//
//  PredictionTrendChart.swift
//  Follower
//
//  Lambda: 粉丝预测区间时序图（Swift Charts）— v1.6 Actual→Forecast Fan Chart。
//
//  视觉叙事（Actual → Forecast → Uncertainty）：
//  - 历史 = 主色实线（唯一"过去"身份）
//  - 预测 = accent 色虚线（唯一"未来"身份）+ 95% 淡背景带 + 80% 主区间带
//  - Today = 灰虚线 + "今天"标签（语义明确）
//  - 终点不做数值标注（Hero 负责"答案"，图负责"过程"，避免数字重复三遍）
//
//  交互（详情态）：
//  - 按住/横向拖动 → Selection（Rule + Point + Tooltip）
//  - Tooltip 按选中位置智能避让（左选右出 / 右选左出 / 中间上方）
//  - 历史点显示"实际值"，预测点显示"预计 + 80%/95% 区间"
//  - 交互状态（selectedDate）留在 View 层，不进 ViewModel
//
//  compact 模式（Dashboard 卡片）：静态渲染，无交互。

import SwiftUI
import Charts

/// 粉丝预测区间时序图 — Actual → Forecast Fan Chart
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
    /// 逐日累计增长中位数
    let dailyMedian: [Double]
    /// 逐日累计增长 90% 分位 — 80% 带上界
    let dailyQ90: [Double]
    /// 逐日累计增长 97.5% 分位 — 95% 带上界
    let dailyUpper: [Double]

    var compact: Bool = false

    /// 交互状态（UI 状态，不进 VM）
    @State private var selectedIndex: Int?
    @State private var tooltipPos: AnnotationPosition = .top

    /// 预测段日期序列（forecastStart + 0...n−1 天）
    private var forecastDates: [Date] {
        let cal = Calendar.current
        return dailyMedian.indices.map { cal.date(byAdding: .day, value: $0, to: forecastStart) ?? forecastStart }
    }

    /// 动态 Y 轴域 — 历史 + 预测区间范围 + 12% 安全 padding（视觉稳定，不过度紧缩）
    private var yDomain: ClosedRange<Double> {
        var values = historical.map(\.1)
        values.append(contentsOf: forecastDates.indices.flatMap { i in
            [baseFollowers + dailyLower[i], baseFollowers + dailyUpper[i],
             baseFollowers + dailyMedian[i]]
        })
        guard let minValue = values.min(), let maxValue = values.max() else { return 0...1 }
        let range = maxValue - minValue
        let padding = max(range * 0.12, maxValue * 0.004)
        return (minValue - padding)...(maxValue + padding)
    }

    var body: some View {
        Group {
            if compact {
                chartContent
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
            } else {
                chartContent
                    .chartYScale(domain: yDomain)
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
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            select(at: value.location.x, proxy: proxy, geometry: geometry)
                                        }
                                        .onEnded { _ in
                                            selectedIndex = nil
                                        }
                                )
                        }
                    }
            }
        }
    }

    // MARK: - Interaction

    /// 拖动映射：x 坐标 → 最近预测日期索引 + Tooltip 避让方向
    private func select(at x: CGFloat, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let date: Date = proxy.value(atX: x) else { return }
        if let nearest = forecastDates.enumerated().min(by: {
            abs($0.element.timeIntervalSince(date)) < abs($1.element.timeIntervalSince(date))
        }) {
            selectedIndex = nearest.offset
            tooltipPos = tooltipPosition(for: nearest.element, proxy: proxy, geometry: geometry)
        }
    }

    /// 选中日期（预测区日期；nil = 未选中）
    private var selectedDate: Date? {
        guard let selectedIndex else { return nil }
        return forecastDates[selectedIndex]
    }

    /// Tooltip 避让方向：选中点 x 在 domain 左/中/右
    private func tooltipPosition(for date: Date, proxy: ChartProxy, geometry: GeometryProxy) -> AnnotationPosition {
        guard let plot = proxy.plotFrame else { return .top }
        let frame = geometry[plot]
        guard let x = proxy.position(forX: date) else { return .top }
        let midX = frame.origin.x + frame.size.width / 2
        if x < midX - frame.size.width * 0.25 { return .trailing }
        if x > midX + frame.size.width * 0.25 { return .leading }
        return .top
    }

    /// Tooltip 内容（历史点 = 实际值；预测点 = 预计 + 区间）
    private func tooltipText(for index: Int) -> String {
        let date = forecastDates[index]
        let day = date.formatted(.dateTime.month().day())
        let median = Int((baseFollowers + dailyMedian[index]).rounded()).formatted(.number)
        let lo80 = Int((baseFollowers + dailyQ10[index]).rounded()).formatted(.number)
        let hi80 = Int((baseFollowers + dailyQ90[index]).rounded()).formatted(.number)
        let lo95 = Int((baseFollowers + dailyLower[index]).rounded()).formatted(.number)
        let hi95 = Int((baseFollowers + dailyUpper[index]).rounded()).formatted(.number)
        return "\(day)\n\(loc(L10n.Premium.predictionForecast)) \(median)\n\(loc(L10n.Premium.likelyRange80)) \(lo80)–\(hi80)\n\(loc(L10n.Premium.likelyRange95)) \(lo95)–\(hi95)"
    }

    // MARK: - Chart Content

    private var chartContent: some View {
        let forecastColor = theme.accentSecondary
        return Chart {
            // ── 95% 极淡背景带（更大可能空间，不抢视觉）──
            ForEach(forecastDates.indices, id: \.self) { i in
                AreaMark(
                    x: .value("Date", forecastDates[i]),
                    yStart: .value("low95", baseFollowers + dailyLower[i]),
                    yEnd: .value("high95", baseFollowers + dailyUpper[i])
                )
                .foregroundStyle(forecastColor.opacity(0.09))
                .interpolationMethod(.linear)
                .alignsMarkStylesWithPlotArea(true)
                .zIndex(0)
            }

            // ── 80% 主区间带（核心不确定性表达）──
            ForEach(forecastDates.indices, id: \.self) { i in
                AreaMark(
                    x: .value("Date", forecastDates[i]),
                    yStart: .value("low80", baseFollowers + dailyQ10[i]),
                    yEnd: .value("high80", baseFollowers + dailyQ90[i])
                )
                .foregroundStyle(forecastColor.opacity(0.20))
                .interpolationMethod(.linear)
                .alignsMarkStylesWithPlotArea(true)
                .zIndex(0)
            }

            // ── 预测中位数（唯一预测线：accent 色虚线，与历史身份鲜明区分）──
            ForEach(forecastDates.indices, id: \.self) { i in
                LineMark(
                    x: .value("Date", forecastDates[i]),
                    y: .value("Median", baseFollowers + dailyMedian[i])
                )
                .foregroundStyle(forecastColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 5]))
                .interpolationMethod(.linear)
                .zIndex(1)
            }

            // ── 历史实线（主色，唯一"过去"身份）──
            ForEach(historical, id: \.0) { date, value in
                LineMark(
                    x: .value("Date", date),
                    y: .value("Followers", value)
                )
                .foregroundStyle(theme.chartLine)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)
                .zIndex(2)
            }

            // ── Today 分界线 + "今天"标签（语义明确）──
            RuleMark(x: .value("Today", forecastStart))
                .foregroundStyle(Color.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .annotation(position: .top, alignment: .trailing, spacing: 2) {
                    Text(loc(L10n.Trends.today))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .zIndex(3)

            // ── Selection（交互态：Rule + Point + Tooltip）──
            if !compact, let selectedIndex, let date = selectedDate {
                // 选中竖线
                RuleMark(x: .value("Selected", date))
                    .foregroundStyle(forecastColor.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .zIndex(4)

                // 选中点（预测中位）
                PointMark(
                    x: .value("Date", date),
                    y: .value("Median", baseFollowers + dailyMedian[selectedIndex])
                )
                .symbolSize(70)
                .foregroundStyle(forecastColor)
                .zIndex(5)

                // Tooltip（智能避让：左选右出 / 右选左出 / 中上）
                RuleMark(x: .value("Selected", date))
                    .annotation(position: tooltipPos, spacing: 6) {
                        Text(tooltipText(for: selectedIndex))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(theme.cardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.divider, lineWidth: 0.5))
                    }
                    .zIndex(6)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
//  MARK: - Preview
// ═══════════════════════════════════════════════════════

/// 生成与真实使用一致的示例数据（确定性公式，无随机 → 多次预览结果稳定）。
private func samplePredictionChartData() -> (
    historical: [(Date, Double)], forecastStart: Date, base: Double,
    lower: [Double], q10: [Double], median: [Double], q90: [Double], upper: [Double]
) {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())

    let historical: [(Date, Double)] = (0..<90).map { i in
        let date = cal.date(byAdding: .day, value: -(89 - i), to: today)!
        return (date, 11_200.0 + 3.0 * Double(i) + Double((i * 7) % 9))
    }
    let base = historical.last!.1

    let median: [Double] = (0...30).map { x -> Double in
        let d = Double(x)
        return 4.0 * d + 0.03 * d * d
    }
    let q10 = median.map { $0 - 40 }
    let q90 = median.map { $0 + 40 }
    let lower = median.map { $0 - 95 }
    let upper = median.map { $0 + 95 }
    return (historical, today, base, lower, q10, median, q90, upper)
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
        dailyMedian: d.median,
        dailyQ90: d.q90,
        dailyUpper: d.upper
    )
    .frame(height: 240)
    .padding()
}

/// compact（Dashboard 主卡片内嵌）：隐藏双轴，无交互
#Preview("Compact Card") {
    let d = samplePredictionChartData()
    PredictionTrendChart(
        historical: d.historical,
        forecastStart: d.forecastStart,
        baseFollowers: d.base,
        dailyLower: d.lower,
        dailyQ10: d.q10,
        dailyMedian: d.median,
        dailyQ90: d.q90,
        dailyUpper: d.upper,
        compact: true
    )
    .frame(height: 110)
    .padding()
    .background(.regularMaterial)
}
