//
//  PredictionDetailView.swift
//  Follower
//
//  Lambda: Premium 详情 — 粉丝预测（v0.15-alpha 贝叶斯模型）。
//  主图：历史实线 + 未来中位数虚线 + 50/80/95% 三层预测区间带 + "今天"线；
//  关键数字行：预计粉丝数 / 80% 预测区间 / 增长概率。
//  冷启动（result 为 nil）→ 空态提示（不渲染图表，杜绝误导性单线折线）。
//

import SwiftUI
import Charts  // chartLegend(.hidden) — 图表修饰符来自 Charts 模块

/// Premium 详情页：粉丝预测 — 区间时序图 + 关键数字
struct PredictionDetailView: View {
    @Environment(\.theme) private var theme

    /// 预测下月粉丝数（预测总数 = 当前 + 累计增长中位数）
    let predicted: Int

    /// 历史粉丝数（升序，带日期）
    let historical: [(Date, Double)]

    /// 贝叶斯预测结果（含逐日区间分位 / 增长概率）；nil = 冷启动
    let result: PredictionResult?

    /// 当前粉丝数（区间带纵轴基准）
    let baseFollowers: Double

    /// 90 天窗口快照天数 — 冷启动诊断显示（v0.15.1）
    let dataDays: Int

    var body: some View {
        ZStack {
            // Theme background gradient
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 预测值 Hero 卡片
                    heroCard

                    // 主图：历史 + 预测区间带（冷启动 → 空态提示，不再回退单线折线）
                    if hasForecast {
                        PredictionTrendChart(
                            historical: historical,
                            forecastStart: forecastStart,
                            baseFollowers: baseFollowers,
                            dailyLower: daily(result?.dailyLower),
                            dailyQ10: daily(result?.dailyQ10),
                            dailyMedian: daily(result?.dailyMedian),
                            dailyQ90: daily(result?.dailyQ90),
                            dailyUpper: daily(result?.dailyUpper)
                        )
                        .frame(height: 240)
                        .padding(.horizontal)
                        .chartLegend(.hidden)
                    } else {
                        forecastUnavailableView
                    }

                    // 关键数字行（仅贝叶斯结果）
                    if hasForecast, let result {
                        keyFigures(result)
                    }

                    // 预测说明文字
                    captionText
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.followerPrediction))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 子视图

    /// Hero 数字卡片 — 最终预测值 + 预计增长（vs 当前粉丝数）
    private var heroCard: some View {
        let growth = Int((Double(predicted) - baseFollowers).rounded())
        let growthPct = baseFollowers > 0 ? Double(growth) / baseFollowers * 100 : 0
        return VStack(spacing: 6) {
            Text("~\(predicted.formatted(.number))")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Text(loc(L10n.Premium.predictedFollowersNext))
                .font(.subheadline).foregroundColor(.secondary)

            if growth != 0 {
                HStack(spacing: 6) {
                    Image(systemName: growth > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(growth > 0 ? "+" : "")\(growth.formatted(.number)) · \(growthPct >= 0 ? "+" : "")\(String(format: "%.1f", growthPct))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(growth > 0 ? theme.positiveGreen : theme.negativeRed)
                    Text(loc(L10n.Premium.predictedGrowthLabel))
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    /// 是否有逐日预测数据（冷启动判断）
    private var hasForecast: Bool {
        guard let r = result, let median = r.dailyMedian, !median.isEmpty else { return false }
        return true
    }

    /// 预测起点 = 最后历史点日期
    private var forecastStart: Date {
        historical.last?.0 ?? Date()
    }

    /// 逐日数组安全解包（缺失 → 全 0 占位，图表不崩溃）
    private func daily(_ arr: [Double]?) -> [Double] {
        guard let arr, !arr.isEmpty else {
            return [Double](repeating: 0, count: RollingForecast.horizonDays + 1)
        }
        return arr
    }

    /// 冷启动空态（数据不足）：不渲染图表，避免误导性单线折线。
    /// 显示当前快照天数（v0.15.1 诊断）——数据不足时一眼定位是数据问题还是模型问题。
    private var forecastUnavailableView: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 28))
                .foregroundColor(theme.textTertiary)
            Text(String(format: loc(L10n.Premium.predictionUnavailable), 30, dataDays))
                .font(.subheadline)
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .padding(.horizontal)
    }

    /// 关键数字行：80% 预测区间 / 预计增长（含相对值）/ 增长概率（clamp 99%）
    @ViewBuilder
    private func keyFigures(_ result: PredictionResult) -> some View {
        let q10 = (result.dailyQ10?.last ?? 0) + baseFollowers
        let q90 = (result.dailyQ90?.last ?? 0) + baseFollowers
        let growth = Double(predicted) - baseFollowers
        let growthPct = baseFollowers > 0 ? growth / baseFollowers * 100 : 0
        // v1.4：概率封顶 99% — P=1.0 显示"100%"会给用户虚假确定性
        let probability = min((result.probabilityPositive ?? 0), 0.99)

        VStack(spacing: 12) {
            HStack {
                figureBlock(
                    title: loc(L10n.Premium.likelyRange80),
                    value: "\(Int(q10).formatted(.number)) – \(Int(q90).formatted(.number))"
                )
                Divider().frame(height: 36)
                figureBlock(
                    title: loc(L10n.Premium.predictedGrowthLabel),
                    value: "\(growth >= 0 ? "+" : "")\(Int(growth.rounded()).formatted(.number)) · \(growthPct >= 0 ? "+" : "")\(String(format: "%.1f", growthPct))%"
                )
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(theme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // 增长概率（独立行，更醒目）
            VStack(spacing: 2) {
                Text(probability.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(theme.positiveGreen)
                Text(loc(L10n.Premium.growthProbability))
                    .font(.caption2).foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(theme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    /// 单个数字块（标题 + 值）
    private func figureBlock(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 底部说明文字 — 仅冷启动（无预测数据）时提示数据不足；
    /// 有预测数据时不显示任何技术性说明（v0.16：模型名称/可信区间说明已移除）
    private var captionText: some View {
        Group {
            if !hasForecast {
                Text(loc(L10n.Premium.predictionNeedsData))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
}
