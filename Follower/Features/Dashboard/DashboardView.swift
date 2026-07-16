//
//  DashboardView.swift
//  Follower
//
//  v3 — 完全按照参考设计图重构:
//      浅灰背景 + 白色卡片 + 蓝色强调
//      Profile Header → Follower Card → Key Metrics Card →
//      Growth Insights Card → Recent Posts Card → Premium Grid Card
//

import SwiftUI

// ═══════════════════════════════════════════════════════
//  MARK: - DashboardCard Modifier
//  白色圆角卡片 + 细微阴影（匹配参考图）
// ═══════════════════════════════════════════════════════

private struct DashboardCard: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.useLiquidGlass) private var useLiquidGlass

    func body(content: Content) -> some View {
        if useLiquidGlass {
            // Liquid Glass 模式: Material 毛玻璃 + theme.cardSurface 半透明色叠层
            content
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
                        RoundedRectangle(cornerRadius: 16).fill(theme.cardSurface)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(theme.isDark ? 0.10 : 0.05), radius: 8, y: 2)
        } else {
            // 非 Liquid Glass (如 Mono Stone): 直接用 cardSurface
            content
                .background(theme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
    }
}

extension View {
    fileprivate func dashboardCard() -> some View { modifier(DashboardCard()) }
}

// ═══════════════════════════════════════════════════════
//  MARK: - DashboardView (Root)
// ═══════════════════════════════════════════════════════

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: DashboardViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        let _ = updateSyncState()

        NavigationStack {
            Group {
                if viewModel.accounts.isEmpty {
                    emptyOrErrorView
                } else if let error = viewModel.errorMessage {
                    errorView(error: error)
                } else if viewModel.latestSnapshot != nil {
                    ScrollView {
                        VStack(spacing: 12) {
                            AccountBar(
                                accounts: viewModel.accounts,
                                selectedAccountId: viewModel.selectedAccountId,
                                onSelect: { id in viewModel.selectAccount(id) }
                            )
                            FollowerSection(
                                followersCount: viewModel.latestSnapshot!.followersCount,
                                delta: viewModel.followerDelta,
                                deltaPercent: viewModel.followerDeltaPercent,
                                sparklineData: viewModel.sparklineData,
                                accountName: viewModel.accounts.first(where: { $0.id == viewModel.selectedAccountId })?.username ?? ""
                            )
                            KeyMetricsSection(
                                engagementRate: viewModel.latestSnapshot?.engagementRate ?? 0,
                                reach: viewModel.latestSnapshot?.totalViews ?? 0,
                                posts: viewModel.latestSnapshot?.mediaCount ?? 0,
                                engagementDelta: viewModel.engagementDelta,
                                reachDelta: viewModel.reachDelta,
                                postsDelta: viewModel.postsDelta
                            )
                            GrowthInsightsSection(
                                aiSummary: viewModel.aiSummary,
                                contentTip: viewModel.contentTip,
                                followerDelta: viewModel.followerDelta,
                                sparklineData: viewModel.sparklineData
                            )
                            RecentPostsSection(posts: viewModel.recentPosts)
                            PremiumInsightsSection(
                                viewModel: viewModel
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .scrollContentBackground(.hidden)
                    .background(
                        LinearGradient(
                            colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                } else if viewModel.isLoading {
                    ProgressView(loc(L10n.Common.loading))
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .background(
                            LinearGradient(
                                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    EmptyStateView(
                        icon: "arrow.triangle.2.circlepath",
                        title: loc(L10n.Dashboard.noDataTitle),
                        message: loc(L10n.Dashboard.noDataMessage),
                        actionLabel: loc(L10n.Common.syncNow),
                        action: { Task { await viewModel.sync() } }
                    )
                    .background(
                        LinearGradient(
                            colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .refreshable { await viewModel.loadAccounts() }
        }
        .task { await viewModel.loadAccounts() }
    }

    // MARK: - Helpers

    private var emptyOrErrorView: some View {
        EmptyStateView(
            icon: "person.crop.circle.badge.exclamationmark",
            title: loc(L10n.Dashboard.noAccountTitle),
            message: loc(L10n.Dashboard.noAccountMessage),
            actionLabel: loc(L10n.Dashboard.connectAccount),
            action: {}
        )
        .background(
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func errorView(error: String) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                ErrorBanner(
                    message: error,
                    onDismiss: { viewModel.errorMessage = nil },
                    onRetry: { Task { await viewModel.loadAccounts() } }
                )
            }
            .padding(.horizontal, 16)
        }
        .background(
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .scrollContentBackground(.hidden)
    }

    private func updateSyncState() {
        if viewModel.accounts.isEmpty {
            appState.syncState = .noAccount
        } else if viewModel.latestSnapshot != nil {
            appState.syncState = .dataReady
        } else if viewModel.isLoading || viewModel.isSyncing {
            appState.syncState = .syncing
        } else {
            appState.syncState = .readyToSync
        }
    }

    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.isSyncing {
                ProgressView()
            } else {
                Button {
                    Task { await viewModel.sync() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .disabled(viewModel.selectedAccountId == nil)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
//  MARK: - 1. AccountBar
//  参考图: 顶部 Profile Header — 头像 + 用户名 + 账户类型
// ═══════════════════════════════════════════════════════

private struct AccountBar: View {
    let accounts: [Account]
    let selectedAccountId: Int64?
    let onSelect: (Int64) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            // 头像
            Circle()
                .fill(theme.accentPrimary.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.accentPrimary)
                }

            // 用户名 + 账户类型
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(selectedAccount?.username ?? "")")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                    Text(loc(L10n.Dashboard.accountType))
                        .font(.system(size: 12))
                }
                .foregroundColor(theme.textSecondary)
            }

            Spacer()

            // 多账户切换指示
            if accounts.count > 1 {
                Menu {
                    ForEach(accounts, id: \.id) { account in
                        Button {
                            if let id = account.id { onSelect(id) }
                        } label: {
                            HStack {
                                Text("@\(account.username)")
                                if account.id == selectedAccountId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private var selectedAccount: Account? {
        accounts.first(where: { $0.id == selectedAccountId })
    }
}

// ═══════════════════════════════════════════════════════
//  MARK: - 2. FollowerSection
//  参考图: 白色卡片 — 标题 + 时间选择器 / 大数字 + delta / 折线图(含坐标轴)
// ═══════════════════════════════════════════════════════

private struct FollowerSection: View {
    let followersCount: Int
    let delta: Int
    let deltaPercent: Double
    let sparklineData: [Double]
    let accountName: String

    @Environment(\.theme) private var theme

    var body: some View {
        NavigationLink {
            FollowerDetailView(
                currentFollowers: followersCount,
                delta: delta,
                deltaPercent: deltaPercent,
                sparklineData: sparklineData,
                accountName: accountName
            )
        } label: {
            VStack(spacing: 0) {
                // ── 顶部: 标题 + 时间段 ──
                HStack {
                    HStack(spacing: 4) {
                        Text(loc(L10n.Dashboard.followersTotal))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        Text("近7天")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.textTertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
                .padding(.bottom, 8)

                // ── 大数字 + Delta ──
                VStack(alignment: .leading, spacing: 2) {
                    Text(followersCount.formatted(.number))
                        .font(.system(size: 36, weight: .bold, design: .default))
                        .foregroundColor(theme.textPrimary)
                        .tracking(-0.5)

                    HStack(spacing: 4) {
                        HStack(spacing: 2) {
                            Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 12, weight: .semibold))
                            Text(abs(delta).formatted(.number))
                                .font(.system(size: 13, weight: .semibold))
                            if deltaPercent != 0 {
                                Text("(\(String(format: "%+.1f%%", deltaPercent)))")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        .foregroundColor(delta >= 0 ? theme.positiveGreen : theme.negativeRed)

                        Text("vs 上周")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTertiary)
                    }
                }
                .padding(.bottom, 12)

                // ── 折线图 (含坐标轴) ──
                if sparklineData.count >= 2 {
                    FollowerLineChart(data: sparklineData)
                        .frame(height: 140)
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .dashboardCard()
    }
}

// ═══════════════════════════════════════════════════════
//  MARK: - 2a. FollowerLineChart
//  参考图: 蓝色折线 + 浅蓝渐变填充 + X轴日期 + Y轴数值
// ═══════════════════════════════════════════════════════

private struct FollowerLineChart: View {
    let data: [Double]

    @Environment(\.theme) private var theme

    /// Y 轴上下留白比例
    private let yPadding: CGFloat = 0.15
    /// 左侧 Y 轴标签宽度
    private let yAxisWidth: CGFloat = 36
    /// 底部 X 轴标签高度
    private let xAxisHeight: CGFloat = 18

    var body: some View {
        let minVal = data.min() ?? 0
        let maxVal = data.max() ?? 1
        let range = max(maxVal - minVal, 1)
        let paddedMin = minVal - range * yPadding
        let paddedMax = maxVal + range * yPadding
        let paddedRange = paddedMax - paddedMin

        VStack(spacing: 0) {
            // 图表主体 + Y 轴
            HStack(alignment: .top, spacing: 4) {
                // Y 轴标签
                VStack(alignment: .trailing, spacing: 0) {
                    Text(formatK(paddedMax))
                        .font(.system(size: 10))
                        .foregroundColor(theme.textTertiary)
                    Spacer()
                    Text(formatK(paddedMin))
                        .font(.system(size: 10))
                        .foregroundColor(theme.textTertiary)
                }
                .frame(width: yAxisWidth)

                // 折线 + 渐变填充
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    ZStack {
                        // 渐变填充
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: h))
                            for (i, value) in data.enumerated() {
                                let x = data.count <= 1 ? 0 : CGFloat(i) / CGFloat(data.count - 1) * w
                                let y = h - CGFloat((value - paddedMin) / paddedRange) * h
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            if data.count > 1 {
                                path.addLine(to: CGPoint(x: w, y: h))
                            }
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.accentPrimary.opacity(0.18),
                                    theme.accentPrimary.opacity(0.02),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // 折线
                        Path { path in
                            for (i, value) in data.enumerated() {
                                let x = data.count <= 1 ? 0 : CGFloat(i) / CGFloat(data.count - 1) * w
                                let y = h - CGFloat((value - paddedMin) / paddedRange) * h
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(
                            theme.accentPrimary,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )

                        // 末端圆点
                        if let lastVal = data.last {
                            let lastX = w
                            let lastY = h - CGFloat((lastVal - paddedMin) / paddedRange) * h
                            Circle()
                                .fill(theme.accentPrimary)
                                .frame(width: 6, height: 6)
                                .position(x: lastX, y: lastY)
                        }
                    }
                }
            }

            // X 轴日期标签
            HStack(spacing: 0) {
                Spacer().frame(width: yAxisWidth + 4) // 与图表左对齐
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        ForEach(0..<chartDates.count, id: \.self) { i in
                            Text(chartDates[i])
                                .font(.system(size: 10))
                                .foregroundColor(theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : (i == chartDates.count - 1 ? .trailing : .center))
                        }
                    }
                    .frame(width: geo.size.width, height: xAxisHeight)
                }
            }
        }
    }

    private var chartDates: [String] {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return (0..<min(data.count, 7)).reversed().compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: Date())
        }.map { fmt.string(from: $0) }
    }

    private func formatK(_ n: Double) -> String {
        if abs(n) >= 1000 { return String(format: "%.1fK", n / 1000) }
        return String(format: "%.0f", n)
    }
}

// ═══════════════════════════════════════════════════════
//  MARK: - 3. KeyMetricsSection
//  参考图: 白色卡片 — 3 列指标（互动率 / 覆盖人数 / 帖子数）
//  每列: 图标 + 标签 + 大数字 + delta
// ═══════════════════════════════════════════════════════

private struct KeyMetricsSection: View {
    let engagementRate: Double
    let reach: Int
    let posts: Int
    let engagementDelta: Double
    let reachDelta: Int
    let postsDelta: Int

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            metricColumn(
                icon: "heart.fill",
                label: loc(L10n.Dashboard.engagementRate),
                value: String(format: "%.1f%%", engagementRate),
                deltaText: deltaText(engagementDelta, unit: "%", isPercent: true),
                isPositive: engagementDelta >= 0
            )

            Divider().padding(.vertical, 8)

            metricColumn(
                icon: "eye.fill",
                label: loc(L10n.Dashboard.reach),
                value: formatCompact(reach),
                deltaText: deltaText(Double(reachDelta), unit: "", isPercent: false),
                isPositive: reachDelta >= 0
            )

            Divider().padding(.vertical, 8)

            metricColumn(
                icon: "doc.text.fill",
                label: loc(L10n.Dashboard.posts),
                value: "\(posts)",
                deltaText: deltaText(Double(postsDelta), unit: "", isPercent: false),
                isPositive: postsDelta >= 0
            )
        }
        .padding(16)
        .dashboardCard()
    }

    private func metricColumn(icon: String, label: String, value: String, deltaText: String, isPositive: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(theme.accentPrimary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.textPrimary)

            Text(deltaText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isPositive ? theme.accentPrimary : theme.negativeRed)
        }
        .frame(maxWidth: .infinity)
    }

    private func deltaText(_ val: Double, unit: String, isPercent: Bool) -> String {
        let prefix = val >= 0 ? "↑ " : "↓ "
        if isPercent {
            return "\(prefix)\(String(format: "%+.1f", val))\(unit)"
        }
        return "\(prefix)\(formatCompact(Int(val)))"
    }

    private func formatCompact(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// ═══════════════════════════════════════════════════════
//  MARK: - 4. GrowthInsightsSection
//  参考图: 白色卡片 — 左侧 AI 文本洞察 + 右侧柱状图
//  标题: "增长洞察" + 星标图标
// ═══════════════════════════════════════════════════════

private struct GrowthInsightsSection: View {
    let aiSummary: String
    let contentTip: String
    let followerDelta: Int
    let sparklineData: [Double]

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // ── 左侧: 文本洞察 ──
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                    Text(loc(L10n.Dashboard.growthInsights))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(theme.accentPrimary)

                Text(insightHeadline)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(insightDetail)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // ── 右侧: 柱状图 ──
            if dailyGrowth.count >= 2 {
                WeeklyBarChart(data: dailyGrowth)
                    .frame(width: 100, height: 80)
            }
        }
        .padding(16)
        .dashboardCard()
    }

    // MARK: - Data Derivation

    private var dailyGrowth: [Double] {
        guard sparklineData.count >= 2 else { return [] }
        return zip(sparklineData.dropFirst(), sparklineData).map { max(0, $0.0 - $0.1) }
    }

    private var insightHeadline: String {
        if followerDelta > 0 {
            return loc(L10n.Dashboard.growthPositiveHeadline)
        } else if followerDelta < 0 {
            return loc(L10n.Dashboard.growthNegativeHeadline)
        }
        return loc(L10n.Dashboard.growthNeutralHeadline)
    }

    private var insightDetail: String {
        if !aiSummary.isEmpty { return aiSummary }
        if !contentTip.isEmpty { return contentTip }
        return loc(L10n.Dashboard.growthDefaultDetail)
    }
}

// ═══════════════════════════════════════════════════════
//  MARK: - 4a. WeeklyBarChart
//  参考图: 蓝色渐变柱状图，7 根柱子代表每日增长
// ═══════════════════════════════════════════════════════

private struct WeeklyBarChart: View {
    let data: [Double]

    @Environment(\.theme) private var theme

    var body: some View {
        let maxVal = data.max() ?? 1
        let barCount = min(data.count, 7)
        let recentData = Array(data.suffix(barCount))

        VStack(spacing: 0) {
            // 柱子
            GeometryReader { geo in
                HStack(spacing: 4) {
                    ForEach(0..<recentData.count, id: \.self) { i in
                        let ratio = maxVal > 0 ? CGFloat(recentData[i] / maxVal) : 0
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [theme.accentPrimary, theme.accentSecondary],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: (geo.size.width - CGFloat(recentData.count - 1) * 4) / CGFloat(recentData.count), height: max(geo.size.height * ratio, 4))
                        }
                    }
                }
            }

            // 日期标签
            HStack(spacing: 0) {
                ForEach(0..<barCount, id: \.self) { i in
                    Text(dayLabel(i))
                        .font(.system(size: 8))
                        .foregroundColor(theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)
        }
    }

    private func dayLabel(_ index: Int) -> String {
        let days = ["日", "一", "二", "三", "四", "五", "六"]
        let cal = Calendar.current
        let offset = index + 1
        guard let date = cal.date(byAdding: .day, value: -offset, to: Date()) else { return "" }
        let weekday = cal.component(.weekday, from: date)
        return days[(weekday - 1) % 7]
    }
}

// ═══════════════════════════════════════════════════════
//  MARK: - 5. RecentPostsSection
//  参考图: 白色卡片 — "最近帖子" + "查看全部" + 帖子行列表
//  每行: 缩略图(60x60) + 标题 + 日期 + 互动数据
// ═══════════════════════════════════════════════════════

private struct RecentPostsSection: View {
    let posts: [MockPost]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // ── 标题行 ──
            HStack {
                Text(loc(L10n.Dashboard.recentContent))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                if !posts.isEmpty {
                    NavigationLink(loc(L10n.Dashboard.viewAll)) {
                        PostListView(posts: MockPostGenerator().generate(count: 20))
                    }
                    .font(.system(size: 13, weight: .medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if posts.isEmpty {
                Text(loc(L10n.Dashboard.noPostsHint))
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                // ── 帖子行 ──
                VStack(spacing: 0) {
                    ForEach(posts) { post in
                        NavigationLink {
                            PostDetailView(post: post)
                        } label: {
                            PostRowView(post: post)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if post.id != posts.last?.id {
                            Divider()
                                .padding(.leading, 76) // 对齐缩略图右侧
                        }
                    }
                }
            }
        }
        .dashboardCard()
    }
}

// ═══════════════════════════════════════════════════════
//  MARK: - 6. PremiumInsightsSection
//  2×2 网格分页滚动 + 底部小点指示器
//  全部 9 项 Premium 入口，每页 4 格，共 3 页
// ═══════════════════════════════════════════════════════

private struct PremiumInsightsSection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    @Environment(\.useLiquidGlass) private var useLiquidGlass

    let viewModel: DashboardViewModel

    @State private var currentPage: Int = 0

    private var isUnlocked: Bool {
        appState.premiumEnabledFlags[PremiumFeatureKey.trendPrediction.rawValue] == true
    }

    /// 每页 4 格
    private let itemsPerPage = 4
    /// 总页数
    private var totalPages: Int {
        let all = allPremiumItems
        return (all.count + itemsPerPage - 1) / itemsPerPage
    }

    // MARK: - 数据源: 全部 9 项

    private var allPremiumItems: [PremiumTileItem] {
        if isUnlocked {
            return [
                .init(icon: "chart.line.uptrend.xyaxis.circle", label: loc(L10n.Premium.followerPrediction),
                      value: viewModel.predictionResult.map {
                          "~\(Int($0.predictedValue).formatted(.number)) \(loc(L10n.Premium.in30Days))"
                      } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "bolt.fill", label: loc(L10n.Premium.activityAnalysis),
                      value: viewModel.activityResult.map {
                          "\($0.label) · \($0.activeDays)/\($0.totalDays) \(loc(L10n.Premium.daysActive))"
                      } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "star.fill", label: loc(L10n.Premium.engagementQuality),
                      value: viewModel.qualityScore.map {
                          "Score: \(String(format: "%.1f", $0.score)) — \($0.label)"
                      } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "person.2.fill", label: loc(L10n.Premium.retentionChurn),
                      value: viewModel.retentionResult.map {
                          "Growth: \(String(format: "%+.1f%%", $0.netGrowthRate)) · Risk: \($0.churnRiskLevel)"
                      } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "globe.asia.australia.fill", label: loc(L10n.Premium.geoDistribution),
                      value: viewModel.geoDistribution.map {
                          "\($0.regions.prefix(2).map(\.name).joined(separator: ", "))"
                      } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "arrow.left.arrow.right", label: loc(L10n.Premium.longTermComparison),
                      value: viewModel.comparisonResult.map {
                          "\($0.direction.rawValue) · \(String(format: "%+.2f", $0.absoluteChange))"
                      } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "person.2.slash", label: loc(L10n.Premium.whoUnfollowedYou),
                      value: "\(viewModel.unfollowList.count) \(loc(L10n.Premium.peopleThisWeek))", locked: false),
                .init(icon: "clock.fill", label: loc(L10n.Premium.bestTimeToPost),
                      value: viewModel.activityResult?.mostActiveDay != nil
                          ? "\(loc(L10n.Premium.mostActiveDay)) \(viewModel.activityResult!.mostActiveDay!)"
                          : viewModel.bestPostingTime, locked: false),
                .init(icon: "lightbulb.fill", label: loc(L10n.Premium.contentStrategy),
                      value: viewModel.aiSummary.isEmpty ? viewModel.contentTip : viewModel.aiSummary, locked: false),
            ]
        } else {
            return [
                .init(icon: "chart.line.uptrend.xy", label: loc(L10n.Premium.followerPrediction), value: "", locked: true),
                .init(icon: "bolt.fill", label: loc(L10n.Premium.activityAnalysis), value: "", locked: true),
                .init(icon: "star.fill", label: loc(L10n.Premium.engagementQuality), value: "", locked: true),
                .init(icon: "person.2.fill", label: loc(L10n.Premium.retentionChurn), value: "", locked: true),
                .init(icon: "globe.asia.australia.fill", label: loc(L10n.Premium.geoDistribution), value: "", locked: true),
                .init(icon: "arrow.left.arrow.right", label: loc(L10n.Premium.longTermComparison), value: "", locked: true),
                .init(icon: "person.2.slash", label: loc(L10n.Premium.whoUnfollowedYou), value: "", locked: true),
                .init(icon: "clock.fill", label: loc(L10n.Premium.bestTimeToPost), value: "", locked: true),
                .init(icon: "lightbulb.fill", label: loc(L10n.Premium.contentStrategy), value: "", locked: true),
            ]
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            // ── 标题行 ──
            HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 13))
                Text(loc(L10n.Premium.premiumInsights))
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .foregroundColor(theme.accentPrimary)
            .padding(.horizontal, 16)

            // ── 分页 2×2 网格 ──
            TabView(selection: $currentPage) {
                ForEach(0..<totalPages, id: \.self) { pageIndex in
                    let items = Array(allPremiumItems[itemsPerPage * pageIndex..<min(itemsPerPage * (pageIndex + 1), allPremiumItems.count)])
                    gridPage(items: items, pageIndex: pageIndex)
                        .tag(pageIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: gridHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // ── 页面指示器小点 ──
            if totalPages > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage
                                  ? theme.accentPrimary
                                  : theme.textTertiary.opacity(0.35))
                            .frame(width: index == currentPage ? 7 : 5,
                                   height: index == currentPage ? 7 : 5)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.top, 2)
            }
        }
        .premiumGate(feature: .trendPrediction)
    }

    // MARK: - 2×2 Grid Page

    private func gridPage(items: [PremiumTileItem], pageIndex: Int) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { localIndex, item in
                    tileCard(item: item, globalIndex: itemsPerPage * pageIndex + localIndex)
                }

                // 最后一页不足 4 格时，用占位补齐保持 2×2
                if items.count < itemsPerPage {
                    ForEach(items.count..<itemsPerPage, id: \.self) { _ in
                        Color.clear
                    }
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    // MARK: - 单个 Tile 卡片

    private func tileCard(item: PremiumTileItem, globalIndex: Int) -> some View {
        Group {
            if item.locked {
                lockedTile(icon: item.icon, label: item.label)
            } else {
                unlockedTile(icon: item.icon, label: item.label, value: item.value, globalIndex: globalIndex)
            }
        }
    }

    /// 解锁态 Tile
    @ViewBuilder
    private func unlockedTile(icon: String, label: String, value: String, globalIndex: Int) -> some View {
        let destination = destinationFor(index: globalIndex)
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentPrimary)
                    .frame(width: 32, height: 32)
                    .background(theme.accentPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(value.isEmpty ? "—" : value)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// 锁定态 Tile
    private func lockedTile(icon: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(theme.textTertiary)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
            }

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("—")
                .font(.system(size: 11))
                .foregroundColor(theme.textTertiary.opacity(0.5))

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// 根据全局 index 返回对应跳转页面
    @ViewBuilder
    private func destinationFor(index: Int) -> some View {
        switch index {
        case 0: PredictionDetailView(predicted: viewModel.predictedFollowers)
        case 1: ActivityDetailView(result: viewModel.activityResult)
        case 2: QualityDetailView(result: viewModel.qualityScore)
        case 3: RetentionDetailView(result: viewModel.retentionResult)
        case 4: GeoDetailView(result: viewModel.geoDistribution)
        case 5: ComparisonDetailView(result: viewModel.comparisonResult)
        case 6: UnfollowListView(followers: viewModel.unfollowList)
        case 7: BestTimeView()
        case 8: ContentStrategyView(tip: viewModel.contentTip)
        default: EmptyView()
        }
    }

    /// 2×2 网格高度: padding(12) * 2 + tile(110) * 2 + spacing(10)
    private var gridHeight: CGFloat { 264 }

    /// 卡片背景: Liquid Glass / 不透明
    @ViewBuilder
    private var cardBackground: some View {
        if useLiquidGlass {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 16).fill(theme.cardSurface)
            }
        } else {
            theme.cardSurface
        }
    }
}

/// Premium Tile 数据模型
private struct PremiumTileItem {
    let icon: String
    let label: String
    let value: String
    let locked: Bool
}

// ═══════════════════════════════════════════════════════
//  MARK: - Preview
// ═══════════════════════════════════════════════════════

#Preview {
    let appState = AppState(databaseManager: DatabaseManager.shared)
    let container = appState.container
    let viewModel = DashboardViewModel(
        snapshotRepo: container.snapshotRepository,
        accountRepo: container.accountRepository,
        syncEngine: container.syncEngine,
        eventRepo: container.eventRepository,
        predictionService: container.predictionService,
        activityService: container.activityAnalysisService,
        retentionService: container.retentionAnalysisService,
        scoringService: container.scoringService,
        geoService: container.geoDistributionService,
        comparisonService: container.comparisonService,
        aiService: container.aiAnalysisService
    )
    DashboardView(viewModel: viewModel)
        .environment(appState)
}
