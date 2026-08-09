//
//  MediaKitPages.swift
//  Follower
//
//  媒体包 PDF 排版 — 6 页初版布局（浅色专业风，A4 竖版）。
//
//  ── 排版修改指引 ──────────────────────────────────────
//  配色：下方 MediaKitStyle 常量，全局生效。
//  页面结构：MediaKitPageBuilder.buildPages（MediaKitPDFGenerator.swift）决定出哪些页、顺序。
//  单页内容：每页一个 struct（MediaKit*Page），改对应实现即可。
//  绘制工具：MediaKitDrawing 扩展提供文本/圆角卡/折线/柱状图，可复用。
//  ─────────────────────────────────────────────────────
//

import UIKit

// MARK: - 样式常量（排版全局）

enum MediaKitStyle {
    static let accent = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1)          // 品牌蓝
    static let text = UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)          // 主文本
    static let secondary = UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1)     // 次级文本
    static let card = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)          // 卡片底色
    static let line = UIColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1)          // 分隔线
    static let positive = UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1)      // 增长
    static let negative = UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1)       // 下降
    static let cover = UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)         // 封面深色
    static let coverSecondary = UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1)

    static let margin: CGFloat = 48                      // 页边距
    static let contentWidth: CGFloat = 595 - margin * 2  // 内容区宽度
    static let cardCorner: CGFloat = 12
    static let chartLineWidth: CGFloat = 2.5
}

// MARK: - 绘制工具（可复用）

extension MediaKitPageDrawing {

    /// 绘制文本（单行/多行均可，自动换行）
    func drawText(
        _ text: String, at point: CGPoint, font: UIFont, color: UIColor,
        maxWidth: CGFloat = .infinity, context: CGContext
    ) {
        context.saveGState()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ]
        let rect = CGRect(origin: point, size: CGSize(width: maxWidth == .infinity ? 4000 : maxWidth, height: 300))
        (text as NSString).draw(in: rect, withAttributes: attrs)
        context.restoreGState()
    }

    /// 绘制圆角卡片
    func drawCard(rect: CGRect, fill: UIColor, context: CGContext) {
        context.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: MediaKitStyle.cardCorner)
        fill.setFill()
        path.fill()
        context.restoreGState()
    }

    /// 绘制水平分隔线
    func drawHLine(at y: CGFloat, fromX: CGFloat, toX: CGFloat, context: CGContext) {
        context.saveGState()
        MediaKitStyle.line.setStroke()
        context.setLineWidth(1)
        context.move(to: CGPoint(x: fromX, y: y))
        context.addLine(to: CGPoint(x: toX, y: y))
        context.strokePath()
        context.restoreGState()
    }

    /// 指标序列子图卡片：标题 + 浅色卡底 + 折线 + 首尾值标注（互动质量页 / 趋势统计页共用）
    func drawSeriesCard(
        title: String, values: [Double], color: UIColor, rect: CGRect, context: CGContext,
        suffix: String = ""
    ) {
        drawText(
            title, at: CGPoint(x: rect.minX, y: rect.minY - 22),
            font: .systemFont(ofSize: 12, weight: .semibold), color: MediaKitStyle.text, context: context
        )
        // 内嵌浅色卡片底
        let bgRect = CGRect(x: rect.minX - 8, y: rect.minY - 8, width: rect.width + 16, height: rect.height + 16)
        drawCard(rect: bgRect, fill: MediaKitStyle.card, context: context)

        drawLineChart(values: values, rect: rect, stroke: color, context: context)

        if let first = values.first, let last = values.last {
            let maxVal = max(first, last)
            let text = "\(Int(first)) → \(Int(last))\(suffix)"
            drawText(
                text, at: CGPoint(x: rect.minX, y: rect.maxY + 6),
                font: .systemFont(ofSize: 10), color: MediaKitStyle.secondary, context: context
            )
            if maxVal > 0 {
                drawText(
                    "\(Int(maxVal))\(suffix)", at: CGPoint(x: rect.maxX - 50, y: rect.minY - 22),
                    font: .systemFont(ofSize: 9), color: MediaKitStyle.secondary,
                    maxWidth: 50, context: context
                )
            }
        }
    }

    /// 绘制折线图（等距横轴 + 纵轴线性缩放，返回图中各点）
    @discardableResult
    func drawLineChart(
        values: [Double], rect: CGRect, stroke: UIColor,
        minValue: Double? = nil, maxValue: Double? = nil, context: CGContext
    ) -> [CGPoint] {
        guard values.count >= 2 else {
            // 点数不足：画一条水平占位线
            drawHLine(at: rect.midY, fromX: rect.minX, toX: rect.maxX, context: context)
            return []
        }
        let minY = minValue ?? (values.min() ?? 0)
        let maxY = maxValue ?? (values.max() ?? 1)
        let span = max(maxY - minY, 1e-6)

        let points: [CGPoint] = values.enumerated().map { idx, v in
            let x = rect.minX + (rect.width * CGFloat(idx) / CGFloat(values.count - 1))
            let y = rect.maxY - (rect.height * CGFloat(v - minY) / CGFloat(span))
            return CGPoint(x: x, y: y)
        }

        context.saveGState()
        let path = UIBezierPath()
        path.move(to: points[0])
        for p in points.dropFirst() { path.addLine(to: p) }
        stroke.setStroke()
        path.lineWidth = MediaKitStyle.chartLineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()

        // 首尾端点
        let dotFill = UIColor.white
        for p in [points.first!, points.last!] {
            context.setFillColor(stroke.cgColor)
            context.fillEllipse(in: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9))
            context.setFillColor(dotFill.cgColor)
            context.fillEllipse(in: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4))
        }
        context.restoreGState()
        return points
    }

    /// 绘制柱状图（横向柱条：值越大柱越长）
    func drawBarChart(
        items: [(label: String, value: Int, color: UIColor)], rect: CGRect, context: CGContext
    ) {
        let total = items.map(\.value).reduce(0, +)
        let rowHeight = rect.height / CGFloat(max(items.count, 1))
        let barMaxWidth = rect.width * 0.55

        for (idx, item) in items.enumerated() {
            let rowY = rect.minY + rowHeight * CGFloat(idx) + rowHeight * 0.5

            // 标签（右侧）
            drawText(
                item.label, at: CGPoint(x: rect.maxX - 120, y: rowY - 8),
                font: .systemFont(ofSize: 10, weight: .medium), color: MediaKitStyle.secondary,
                maxWidth: 110, context: context
            )

            // 数值 + 占比（标签左侧）
            let share = total > 0 ? Double(item.value) / Double(total) * 100 : 0
            drawText(
                "\(item.value) (\(String(format: "%.0f%%", share)))",
                at: CGPoint(x: rect.minX + barMaxWidth + 12, y: rowY - 7),
                font: .systemFont(ofSize: 10, weight: .semibold), color: MediaKitStyle.text,
                maxWidth: 90, context: context
            )

            // 柱条（左侧，按占比缩放）
            let barWidth = total > 0 ? barMaxWidth * CGFloat(item.value) / CGFloat(total) : 0
            let barRect = CGRect(x: rect.minX, y: rowY - 6, width: max(barWidth, 2), height: 12)
            context.saveGState()
            item.color.setFill()
            UIBezierPath(roundedRect: barRect, cornerRadius: 6).fill()
            context.restoreGState()
        }
    }

    /// 纵向柱状图（趋势页风格：网格线 + 圆角柱 + 顶部数值），值按最大值线性缩放
    func drawVBarChart(
        values: [Double], rect: CGRect, fill: UIColor, context: CGContext,
        maxValue: Double? = nil, showGrid: Bool = true
    ) {
        guard !values.isEmpty else {
            drawHLine(at: rect.midY, fromX: rect.minX, toX: rect.maxX, context: context)
            return
        }
        let maxV = max(maxValue ?? (values.max() ?? 0), 1)
        let slotW = rect.width / CGFloat(values.count)
        let barW = min(slotW * 0.55, 24)
        let corner: CGFloat = min(barW / 2, 4)

        // 水平网格线（4 条虚线）
        if showGrid {
            context.saveGState()
            context.setStrokeColor(MediaKitStyle.line.cgColor)
            context.setLineWidth(0.5)
            context.setLineDash(phase: 0, lengths: [3, 3])
            for i in 1...4 {
                let y = rect.maxY - rect.height * CGFloat(i) / 4
                context.move(to: CGPoint(x: rect.minX, y: y))
                context.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])
            context.restoreGState()
        }

        // 柱（底对齐圆角矩形）
        for (idx, v) in values.enumerated() {
            let h = v > 0 ? max(rect.height * CGFloat(v / maxV), 2) : 0
            let x = rect.minX + slotW * CGFloat(idx) + (slotW - barW) / 2
            let barRect = CGRect(x: x, y: rect.maxY - h, width: barW, height: h)
            context.saveGState()
            fill.setFill()
            UIBezierPath(roundedRect: barRect, cornerRadius: corner).fill()
            context.restoreGState()
        }
    }

    /// 页面底部页码
    func drawPageNumber(_ number: Int, total: Int, context: CGContext) {
        drawText(
            "\(number) / \(total)",
            at: CGPoint(x: MediaKitStyle.margin, y: 842 - 36),
            font: .systemFont(ofSize: 9), color: MediaKitStyle.secondary, context: context
        )
    }
}

// MARK: - 页面标题（内容页共用）

enum MediaKitPageHeader {
    static func draw(title: String, subtitle: String, context: CGContext) {
        drawText(
            title, at: CGPoint(x: MediaKitStyle.margin, y: 56),
            font: .systemFont(ofSize: 22, weight: .bold), color: MediaKitStyle.text, context: context
        )
        drawText(
            subtitle, at: CGPoint(x: MediaKitStyle.margin, y: 90),
            font: .systemFont(ofSize: 11), color: MediaKitStyle.secondary, context: context
        )
        drawHLine(at: 116, fromX: MediaKitStyle.margin, toX: 595 - MediaKitStyle.margin, context: context)
    }

    // MARK: 本 enum 不遵守 MediaKitPageDrawing，helper 就地内联

    /// 绘制文本（单行/多行均可，自动换行）
    private static func drawText(
        _ text: String, at point: CGPoint, font: UIFont, color: UIColor,
        maxWidth: CGFloat = .infinity, context: CGContext
    ) {
        context.saveGState()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ]
        let rect = CGRect(origin: point, size: CGSize(width: maxWidth == .infinity ? 4000 : maxWidth, height: 300))
        (text as NSString).draw(in: rect, withAttributes: attrs)
        context.restoreGState()
    }

    /// 绘制水平分隔线
    private static func drawHLine(at y: CGFloat, fromX: CGFloat, toX: CGFloat, context: CGContext) {
        context.saveGState()
        MediaKitStyle.line.setStroke()
        context.setLineWidth(1)
        context.move(to: CGPoint(x: fromX, y: y))
        context.addLine(to: CGPoint(x: toX, y: y))
        context.strokePath()
        context.restoreGState()
    }
}

// MARK: - 1. 封面

struct MediaKitCoverPage: MediaKitPageDrawing {
    let data: MediaKitData
    let template: MediaKitTemplate

    var pageTitle: String { "Cover" }
    /// 封面为全页视觉页，不画页码
    var showsPageNumber: Bool { false }

    init(data: MediaKitData, template: MediaKitTemplate = .professional) {
        self.data = data
        self.template = template
    }

    func draw(in context: CGContext, pageSize: CGSize) {
        drawBackground(context: context, pageSize: pageSize)

        let midX = pageSize.width / 2

        // 账号类型徽章（胶囊；creative 用白底强调色文字）
        let typeText = accountTypeLabel(data.account.accountType)
        let badgeWidth: CGFloat = CGFloat(typeText.count) * 9 + 32
        let badgeRect = CGRect(x: midX - badgeWidth / 2, y: 240, width: badgeWidth, height: 26)
        context.saveGState()
        if template == .creative {
            UIColor.white.setFill()
        } else {
            MediaKitStyle.accent.setFill()
        }
        UIBezierPath(roundedRect: badgeRect, cornerRadius: 13).fill()
        context.restoreGState()
        drawText(
            typeText, at: CGPoint(x: badgeRect.minX, y: badgeRect.minY + 6),
            font: .systemFont(ofSize: 11, weight: .semibold),
            color: template == .creative ? UIColor(red: 0.88, green: 0.19, blue: 0.42, alpha: 1) : .white,
            maxWidth: badgeWidth, context: context
        )

        // @handle
        drawText(
            "@\(data.account.username)",
            at: CGPoint(x: midX - 250, y: 300),
            font: .systemFont(ofSize: 40, weight: .bold), color: .white,
            maxWidth: 500, context: context
        )

        // 粉丝数（无快照时占位）
        let followers = data.snapshot?.followersCount
        drawText(
            followers.map { formatCompact($0) } ?? "—",
            at: CGPoint(x: midX - 250, y: 380),
            font: .systemFont(ofSize: 64, weight: .bold), color: .white,
            maxWidth: 500, context: context
        )
        drawText(
            loc(L10n.MediaKit.followers),
            at: CGPoint(x: midX - 250, y: 458),
            font: .systemFont(ofSize: 14, weight: .medium), color: MediaKitStyle.coverSecondary,
            maxWidth: 500, context: context
        )

        // 底部：报告日期 + 生成来源
        let dateStr = data.generatedAt.formatted(date: .long, time: .omitted)
        drawText(
            dateStr,
            at: CGPoint(x: midX - 150, y: 720),
            font: .systemFont(ofSize: 12), color: MediaKitStyle.coverSecondary,
            maxWidth: 300, context: context
        )
        drawText(
            loc(L10n.MediaKit.generatedBy),
            at: CGPoint(x: midX - 150, y: 752),
            font: .systemFont(ofSize: 10), color: MediaKitStyle.coverSecondary,
            maxWidth: 300, context: context
        )
    }

    /// 封面背景：creative = 品牌渐变（紫→粉→橙，Instagram 风格），其余 = 深色
    private func drawBackground(context: CGContext, pageSize: CGSize) {
        context.saveGState()
        if template == .creative {
            let colors = [
                UIColor(red: 0.51, green: 0.23, blue: 0.71, alpha: 1).cgColor,  // #833AB4
                UIColor(red: 0.88, green: 0.19, blue: 0.42, alpha: 1).cgColor,  // #E1306C
                UIColor(red: 0.97, green: 0.47, blue: 0.22, alpha: 1).cgColor,  // #F77737
            ]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.55, 1]
            ) {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: pageSize.width, y: pageSize.height),
                    options: []
                )
            }
        } else {
            MediaKitStyle.cover.setFill()
            context.fill(CGRect(origin: .zero, size: pageSize))
        }
        context.restoreGState()
    }

    /// 账号类型 → 中文标签
    private func accountTypeLabel(_ type: String?) -> String {
        switch type?.uppercased() {
        case "BUSINESS": return loc(L10n.MediaKit.businessAccount)
        case "CREATOR": return loc(L10n.MediaKit.creatorAccount)
        default: return loc(L10n.MediaKit.personalAccount)
        }
    }
}

// MARK: - 2. 核心指标

struct MediaKitOverviewPage: MediaKitPageDrawing {
    let data: MediaKitData
    let template: MediaKitTemplate

    var pageTitle: String { "Overview" }

    init(data: MediaKitData, template: MediaKitTemplate = .professional) {
        self.data = data
        self.template = template
    }

    func draw(in context: CGContext, pageSize: CGSize) {
        MediaKitPageHeader.draw(
            title: loc(L10n.MediaKit.coreMetrics), subtitle: loc(L10n.MediaKit.coreMetricsSubtitle),
            context: context
        )

        // 2 列 × 3 行卡片
        let cardWidth = (MediaKitStyle.contentWidth - 16) / 2
        let cardHeight: CGFloat = 120
        let gap: CGFloat = 16
        let startY: CGFloat = 150

        for (idx, row) in data.metricRows.enumerated() {
            let col = idx % 2
            let rowIdx = idx / 2
            let x = MediaKitStyle.margin + CGFloat(col) * (cardWidth + gap)
            let y = startY + CGFloat(rowIdx) * (cardHeight + gap)
            let rect = CGRect(x: x, y: y, width: cardWidth, height: cardHeight)
            drawCard(rect: rect, fill: MediaKitStyle.card, context: context)

            // 指标名
            drawText(
                row.label, at: CGPoint(x: rect.minX + 16, y: rect.minY + 14),
                font: .systemFont(ofSize: 11, weight: .medium), color: MediaKitStyle.secondary,
                maxWidth: cardWidth - 32, context: context
            )
            // 数值
            drawText(
                row.formattedValue, at: CGPoint(x: rect.minX + 16, y: rect.minY + 38),
                font: .systemFont(ofSize: 26, weight: .bold), color: MediaKitStyle.text,
                maxWidth: cardWidth - 32, context: context
            )
            // 环比（绿/红）
            let deltaColor = (row.delta ?? 0) >= 0 ? MediaKitStyle.positive : MediaKitStyle.negative
            let deltaPrefix = (row.delta ?? 0) >= 0 ? "▲ " : "▼ "
            drawText(
                deltaPrefix + row.deltaLabel, at: CGPoint(x: rect.minX + 16, y: rect.minY + 82),
                font: .systemFont(ofSize: 10, weight: .semibold), color: deltaColor,
                maxWidth: cardWidth - 32, context: context
            )
        }
    }
}

// MARK: - 3. 增长趋势（12 周折线）

struct MediaKitGrowthPage: MediaKitPageDrawing {
    let data: MediaKitData
    let template: MediaKitTemplate

    var pageTitle: String { "Growth" }

    init(data: MediaKitData, template: MediaKitTemplate = .professional) {
        self.data = data
        self.template = template
    }

    func draw(in context: CGContext, pageSize: CGSize) {
        MediaKitPageHeader.draw(
            title: loc(L10n.MediaKit.growthTrend), subtitle: loc(L10n.MediaKit.growthTrendSubtitle),
            context: context
        )

        // 摘要条：期初 → 期末 + 净增长
        if let first = data.weeklyGrowth.first, let last = data.weeklyGrowth.last {
            let delta = last.followers - first.followers
            let summaryColor = delta >= 0 ? MediaKitStyle.positive : MediaKitStyle.negative
            let summary = String(
                format: loc(L10n.MediaKit.growthSummary),
                formatCompact(first.followers), formatCompact(last.followers),
                delta >= 0 ? "+" : "", formatCompact(delta)
            )
            drawText(
                summary, at: CGPoint(x: MediaKitStyle.margin, y: 140),
                font: .systemFont(ofSize: 13, weight: .semibold), color: summaryColor,
                maxWidth: MediaKitStyle.contentWidth, context: context
            )
        }

        // 折线图
        let chartRect = CGRect(x: MediaKitStyle.margin, y: 180, width: MediaKitStyle.contentWidth, height: 300)
        drawLineChart(
            values: data.weeklyGrowth.map { Double($0.followers) },
            rect: chartRect, stroke: MediaKitStyle.accent, context: context
        )

        // 首尾日期标注（图下方）
        if let first = data.weeklyGrowth.first, let last = data.weeklyGrowth.last {
            let firstStr = first.date.formatted(.dateTime.month().day())
            let lastStr = last.date.formatted(.dateTime.month().day())
            drawText(
                firstStr, at: CGPoint(x: chartRect.minX, y: chartRect.maxY + 12),
                font: .systemFont(ofSize: 10), color: MediaKitStyle.secondary, context: context
            )
            let lastWidth: CGFloat = 80
            drawText(
                lastStr, at: CGPoint(x: chartRect.maxX - lastWidth, y: chartRect.maxY + 12),
                font: .systemFont(ofSize: 10), color: MediaKitStyle.secondary,
                maxWidth: lastWidth, context: context
            )
        }
    }
}

// MARK: - 4. 内容表现（Top 5 + 类型分布）

struct MediaKitContentPage: MediaKitPageDrawing {
    let data: MediaKitData
    let template: MediaKitTemplate

    var pageTitle: String { "Content" }

    init(data: MediaKitData, template: MediaKitTemplate = .professional) {
        self.data = data
        self.template = template
    }

    func draw(in context: CGContext, pageSize: CGSize) {
        MediaKitPageHeader.draw(
            title: loc(L10n.MediaKit.contentPerformance), subtitle: loc(L10n.MediaKit.contentPerformanceSubtitle),
            context: context
        )

        // Top 5 列表
        let topStartY: CGFloat = 140
        let rowHeight: CGFloat = 44
        drawText(
            loc(L10n.MediaKit.topPosts), at: CGPoint(x: MediaKitStyle.margin, y: topStartY - 24),
            font: .systemFont(ofSize: 13, weight: .semibold), color: MediaKitStyle.text, context: context
        )

        for (idx, post) in data.topPosts.enumerated() {
            let y = topStartY + CGFloat(idx) * rowHeight

            // 序号
            drawText(
                "\(idx + 1)", at: CGPoint(x: MediaKitStyle.margin, y: y + 6),
                font: .systemFont(ofSize: 13, weight: .bold), color: MediaKitStyle.secondary, context: context
            )

            // 类型色块 + 标签
            let typeColor = typeColor(post.type)
            let chipRect = CGRect(x: MediaKitStyle.margin + 28, y: y + 4, width: 44, height: 20)
            context.saveGState()
            typeColor.setFill()
            UIBezierPath(roundedRect: chipRect, cornerRadius: 10).fill()
            context.restoreGState()
            drawText(
                typeLabel(post.type), at: CGPoint(x: chipRect.minX + 3, y: chipRect.minY + 4),
                font: .systemFont(ofSize: 9, weight: .semibold), color: .white,
                maxWidth: 38, context: context
            )

            // 日期
            let dateStr = post.date.formatted(date: .abbreviated, time: .omitted)
            drawText(
                dateStr, at: CGPoint(x: MediaKitStyle.margin + 84, y: y + 7),
                font: .systemFont(ofSize: 10), color: MediaKitStyle.secondary, context: context
            )

            // 点赞 / 评论（右对齐）
            drawText(
                "❤︎ \(formatCompact(post.likes))  💬 \(formatCompact(post.comments))",
                at: CGPoint(x: 595 - MediaKitStyle.margin - 200, y: y + 7),
                font: .systemFont(ofSize: 11, weight: .medium), color: MediaKitStyle.text,
                maxWidth: 200, context: context
            )

            drawHLine(at: y + rowHeight - 4, fromX: MediaKitStyle.margin, toX: 595 - MediaKitStyle.margin, context: context)
        }

        // 类型分布柱状图
        let chartTitleY = topStartY + CGFloat(data.topPosts.count) * rowHeight + 40
        drawText(
            loc(L10n.MediaKit.postTypeDistribution), at: CGPoint(x: MediaKitStyle.margin, y: chartTitleY),
            font: .systemFont(ofSize: 13, weight: .semibold), color: MediaKitStyle.text, context: context
        )
        let chartRect = CGRect(
            x: MediaKitStyle.margin, y: chartTitleY + 28,
            width: MediaKitStyle.contentWidth, height: CGFloat(max(data.postTypeCounts.count, 1)) * 26
        )
        drawBarChart(
            items: data.postTypeCounts.map {
                (label: typeLabel(for: $0.type), value: $0.count, color: typeColor(for: $0.type))
            },
            rect: chartRect, context: context
        )
    }

    /// 帖子类型 → 中文标签（MediaPostType 版，Top 5 列表用）
    private func typeLabel(_ type: MediaPostType) -> String {
        switch type {
        case .image: return loc(L10n.MediaKit.typeImage)
        case .video: return loc(L10n.MediaKit.typeVideo)
        case .carousel: return loc(L10n.MediaKit.typeCarousel)
        }
    }

    /// 帖子类型 → 中文标签（rawValue 字符串版，类型分布统计用）
    private func typeLabel(for rawValue: String) -> String {
        typeLabel(MediaPostType(rawValue: rawValue) ?? .image)
    }

    /// 帖子类型 → 色块色（MediaPostType 版，Top 5 列表用）
    private func typeColor(_ type: MediaPostType) -> UIColor {
        switch type {
        case .image: return MediaKitStyle.accent
        case .video: return UIColor(red: 0.65, green: 0.35, blue: 1.0, alpha: 1)
        case .carousel: return UIColor(red: 0.0, green: 0.68, blue: 0.56, alpha: 1)
        }
    }

    /// 帖子类型 → 色块色（rawValue 字符串版，类型分布统计用）
    private func typeColor(for rawValue: String) -> UIColor {
        typeColor(MediaPostType(rawValue: rawValue) ?? .image)
    }
}

// MARK: - 5. 互动质量（3 条日趋势）

struct MediaKitEngagementPage: MediaKitPageDrawing {
    let data: MediaKitData
    let template: MediaKitTemplate

    var pageTitle: String { "Engagement" }

    init(data: MediaKitData, template: MediaKitTemplate = .professional) {
        self.data = data
        self.template = template
    }

    func draw(in context: CGContext, pageSize: CGSize) {
        MediaKitPageHeader.draw(
            title: loc(L10n.MediaKit.engagementQuality), subtitle: loc(L10n.MediaKit.engagementQualitySubtitle),
            context: context
        )

        // 三个子图：均赞 / 均评 / 互动率
        let chartHeight: CGFloat = 150
        let gap: CGFloat = 36
        let startY: CGFloat = 150

        drawSeriesCard(
            title: loc(L10n.MediaKit.avgLikes),
            values: data.avgLikesSeries,
            color: MediaKitStyle.accent,
            rect: CGRect(x: MediaKitStyle.margin, y: startY, width: MediaKitStyle.contentWidth, height: chartHeight),
            context: context
        )
        drawSeriesCard(
            title: loc(L10n.MediaKit.avgComments),
            values: data.avgCommentsSeries,
            color: UIColor(red: 0.65, green: 0.35, blue: 1.0, alpha: 1),
            rect: CGRect(x: MediaKitStyle.margin, y: startY + (chartHeight + gap), width: MediaKitStyle.contentWidth, height: chartHeight),
            context: context
        )
        drawSeriesCard(
            title: loc(L10n.MediaKit.engagementRate),
            values: data.engagementSeries,
            color: UIColor(red: 0.0, green: 0.68, blue: 0.56, alpha: 1),
            rect: CGRect(x: MediaKitStyle.margin, y: startY + 2 * (chartHeight + gap), width: MediaKitStyle.contentWidth, height: chartHeight),
            context: context,
            suffix: "%"
        )
    }
}

// MARK: - 6. 趋势柱状图（完整模板：6 指标 × 7 周竖柱状图，与趋势页同风格）

struct MediaKitTrendBarsPage: MediaKitPageDrawing {
    let data: MediaKitData
    let template: MediaKitTemplate

    var pageTitle: String { "Trend Bars" }

    init(data: MediaKitData, template: MediaKitTemplate = .professional) {
        self.data = data
        self.template = template
    }

    func draw(in context: CGContext, pageSize: CGSize) {
        MediaKitPageHeader.draw(
            title: loc(L10n.MediaKit.trendBars), subtitle: loc(L10n.MediaKit.trendBarsSubtitle),
            context: context
        )

        // 2 列 × 3 行小柱状图
        let gap: CGFloat = 16
        let cardWidth = (MediaKitStyle.contentWidth - gap) / 2
        let chartHeight: CGFloat = 168
        let startY: CGFloat = 150

        let metrics = TrendsViewModel.visibleMetricTypes
        for (idx, type) in metrics.enumerated() {
            let col = idx % 2
            let rowIdx = idx / 2
            let x = MediaKitStyle.margin + CGFloat(col) * (cardWidth + gap)
            let y = startY + CGFloat(rowIdx) * (chartHeight + 46)

            // 指标名（图上方）
            drawText(
                type.localizedName, at: CGPoint(x: x, y: y - 22),
                font: .systemFont(ofSize: 12, weight: .semibold), color: MediaKitStyle.text,
                maxWidth: cardWidth, context: context
            )

            // 图卡片底
            let chartRect = CGRect(x: x, y: y, width: cardWidth, height: chartHeight)
            drawCard(rect: chartRect, fill: MediaKitStyle.card, context: context)
            let inner = chartRect.insetBy(dx: 14, dy: 14)

            let values = data.weeklySeries[type] ?? []
            drawVBarChart(
                values: values, rect: inner, fill: MediaKitStyle.accent,
                context: context, maxValue: maxValue(for: type, values: values)
            )

            // 首尾数值标注（图下方）
            let maxVal = values.max() ?? 0
            drawText(
                "\(formatCompact(Int(maxVal)))", at: CGPoint(x: inner.minX, y: chartRect.maxY + 6),
                font: .systemFont(ofSize: 9), color: MediaKitStyle.secondary, context: context
            )
            if values.count >= 2 {
                drawText(
                    "\(values.count)w", at: CGPoint(x: inner.maxX - 30, y: chartRect.maxY + 6),
                    font: .systemFont(ofSize: 9), color: MediaKitStyle.secondary,
                    maxWidth: 30, context: context
                )
            }
        }
    }

    /// 各指标独立 y 上限：互动率 % 用 5 的倍数，其余用最大值本身
    private func maxValue(for type: MetricType, values: [Double]) -> Double? {
        guard let maxV = values.max(), maxV > 0 else { return nil }
        switch type {
        case .engagementTrend:
            return ceil(maxV / 5) * 5
        default:
            return nil  // 用数据最大值线性缩放
        }
    }
}

// MARK: - 7. 趋势统计（完整模板：2 页，30 天日窗口；粉丝用 12 周周窗口）

/// 趋势统计页（第 1 页 / 第 2 页）
enum TrendStatsPageIndex {
    case first, second
}

struct MediaKitTrendStatsPage: MediaKitPageDrawing {
    let data: MediaKitData
    let page: TrendStatsPageIndex
    let template: MediaKitTemplate

    var pageTitle: String { page == .first ? "Trend Stats A" : "Trend Stats B" }

    init(data: MediaKitData, page: TrendStatsPageIndex, template: MediaKitTemplate = .professional) {
        self.data = data
        self.page = page
        self.template = template
    }

    func draw(in context: CGContext, pageSize: CGSize) {
        MediaKitPageHeader.draw(
            title: loc(L10n.MediaKit.trendStats), subtitle: loc(L10n.MediaKit.trendStatsSubtitle),
            context: context
        )

        let chartHeight: CGFloat = 150
        let gap: CGFloat = 36
        let startY: CGFloat = 150

        let series: [(title: String, values: [Double], color: UIColor, suffix: String)] = seriesSpecs()

        for (idx, spec) in series.enumerated() {
            drawSeriesCard(
                title: spec.title, values: spec.values, color: spec.color,
                rect: CGRect(
                    x: MediaKitStyle.margin,
                    y: startY + CGFloat(idx) * (chartHeight + gap),
                    width: MediaKitStyle.contentWidth,
                    height: chartHeight
                ),
                context: context, suffix: spec.suffix
            )
        }
    }

    /// 本页的三个指标序列（第 1 页：粉丝 12 周 + 互动率 + 均赞；第 2 页：均评 + 均分享 + 触达）
    private func seriesSpecs() -> [(title: String, values: [Double], color: UIColor, suffix: String)] {
        let series = data.trendSeries
        switch page {
        case .first:
            return [
                (loc(L10n.MediaKit.followers),
                 data.weeklyGrowth.map { Double($0.followers) },
                 MediaKitStyle.accent, ""),
                (loc(L10n.MediaKit.engagementRate),
                 series[.engagementTrend] ?? [],
                 UIColor(red: 0.0, green: 0.68, blue: 0.56, alpha: 1), "%"),
                (loc(L10n.MediaKit.avgLikes),
                 series[.averageLikes] ?? [],
                 MediaKitStyle.accent, ""),
            ]
        case .second:
            return [
                (loc(L10n.MediaKit.avgComments),
                 series[.averageComments] ?? [],
                 UIColor(red: 0.65, green: 0.35, blue: 1.0, alpha: 1), ""),
                (loc(L10n.MediaKit.avgShares),
                 series[.averageShares] ?? [],
                 UIColor(red: 0.95, green: 0.61, blue: 0.07, alpha: 1), ""),
                (loc(L10n.MediaKit.profileViews),
                 series[.profileViews] ?? [],
                 UIColor(red: 0.0, green: 0.68, blue: 0.56, alpha: 1), ""),
            ]
        }
    }
}

// MARK: - 8. 增长建议（决策引擎生成，完整模板）

struct MediaKitDecisionsPage: MediaKitPageDrawing {
    let data: MediaKitData
    let template: MediaKitTemplate

    var pageTitle: String { "Recommendations" }

    init(data: MediaKitData, template: MediaKitTemplate = .professional) {
        self.data = data
        self.template = template
    }

    func draw(in context: CGContext, pageSize: CGSize) {
        MediaKitPageHeader.draw(
            title: loc(L10n.MediaKit.decisions), subtitle: loc(L10n.MediaKit.decisionsSubtitle),
            context: context
        )

        let cardHeight: CGFloat = 168
        let gap: CGFloat = 16
        let startY: CGFloat = 150

        for (idx, card) in data.actionCards.enumerated() {
            let y = startY + CGFloat(idx) * (cardHeight + gap)
            let rect = CGRect(x: MediaKitStyle.margin, y: y, width: MediaKitStyle.contentWidth, height: cardHeight)
            drawCard(rect: rect, fill: MediaKitStyle.card, context: context)

            var cursorY = rect.minY + 16

            // 标题（加粗）
            drawText(
                card.template.displayTitle, at: CGPoint(x: rect.minX + 16, y: cursorY),
                font: .systemFont(ofSize: 14, weight: .bold), color: MediaKitStyle.text,
                maxWidth: rect.width - 32, context: context
            )
            cursorY += 24

            // 原因（次级文本）
            drawText(
                card.template.displayReason, at: CGPoint(x: rect.minX + 16, y: cursorY),
                font: .systemFont(ofSize: 10.5), color: MediaKitStyle.secondary,
                maxWidth: rect.width - 32, context: context
            )
            cursorY += 22

            // 行动列表
            for action in card.template.displayActions {
                drawText(
                    "•  " + action, at: CGPoint(x: rect.minX + 16, y: cursorY),
                    font: .systemFont(ofSize: 10.5, weight: .medium), color: MediaKitStyle.text,
                    maxWidth: rect.width - 32, context: context
                )
                cursorY += 19
            }
        }
    }
}

// MARK: - 9. 结语（数据说明）

struct MediaKitFooterPage: MediaKitPageDrawing {
    let data: MediaKitData
    let template: MediaKitTemplate

    var pageTitle: String { "Footer" }

    init(data: MediaKitData, template: MediaKitTemplate = .professional) {
        self.data = data
        self.template = template
    }

    func draw(in context: CGContext, pageSize: CGSize) {
        MediaKitPageHeader.draw(
            title: loc(L10n.MediaKit.dataNotes), subtitle: loc(L10n.MediaKit.dataNotesSubtitle),
            context: context
        )

        let lines: [String] = [
            loc(L10n.MediaKit.note1),
            loc(L10n.MediaKit.note2),
            loc(L10n.MediaKit.note3),
            loc(L10n.MediaKit.note4),
        ]
        var y: CGFloat = 150
        for line in lines {
            drawText(
                "•  " + line, at: CGPoint(x: MediaKitStyle.margin, y: y),
                font: .systemFont(ofSize: 11), color: MediaKitStyle.text,
                maxWidth: MediaKitStyle.contentWidth, context: context
            )
            y += 30
        }

        // 底部品牌署名
        drawText(
            loc(L10n.MediaKit.generatedBy),
            at: CGPoint(x: MediaKitStyle.margin, y: 760),
            font: .systemFont(ofSize: 10, weight: .medium), color: MediaKitStyle.secondary, context: context
        )
    }
}

// MARK: - 格式化工具

/// 万/千缩写（PDF 内通用）
private func formatCompact(_ value: Int) -> String {
    if value >= 10000 { return String(format: "%.1fw", Double(value) / 10000) }
    if value >= 1000 { return String(format: "%.1fk", Double(value) / 1000) }
    return "\(value)"
}
