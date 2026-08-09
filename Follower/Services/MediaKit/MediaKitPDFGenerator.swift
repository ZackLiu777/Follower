//
//  MediaKitPDFGenerator.swift
//  Follower
//
//  媒体包 PDF 生成管线：
//    MediaKitData → 页面数组（MediaKitPageDrawing）→ UIGraphicsPDFRenderer 逐页绘制
//    → PDFDocument 组装（PDFKit）→ 写入 Documents/MediaKits/。
//
//  排版与管线解耦：排版改动只改页面实现（MediaKitPages.swift），管线不动。
//  可在后台线程调用（UIGraphicsPDFRenderer 线程安全）。
//

import Foundation
import UIKit
import PDFKit

// MARK: - 页面协议

/// 一页排版的契约 — 排版实现只关心「在这个尺寸里画什么」
protocol MediaKitPageDrawing {
    var pageTitle: String { get }
    /// 是否显示页码（封面等全页视觉页关闭）
    var showsPageNumber: Bool { get }
    func draw(in context: CGContext, pageSize: CGSize)
}

extension MediaKitPageDrawing {
    /// 默认显示页码
    var showsPageNumber: Bool { true }
}

// MARK: - 生成器

protocol MediaKitPDFGenerating: Sendable {
    func generate(data: MediaKitData, template: MediaKitTemplate) throws -> URL
}

final class MediaKitPDFGenerator: MediaKitPDFGenerating {

    /// A4 竖版（pt）
    static let pageSize = CGSize(width: 595, height: 842)

    private let pageBuilder: MediaKitPageBuilding

    /// 注入页面构建器 — 排版改动只需替换 pageBuilder
    init(pageBuilder: MediaKitPageBuilding = MediaKitPageBuilder()) {
        self.pageBuilder = pageBuilder
    }

    /// 生成媒体包 PDF 并落盘到 Documents/MediaKits/，返回文件 URL
    func generate(data: MediaKitData, template: MediaKitTemplate = .professional) throws -> URL {
        let pages = pageBuilder.buildPages(data: data, template: template)
        guard !pages.isEmpty else {
            throw MediaKitError.emptyData
        }

        // 1. 逐页绘制 → PDF data（页码统一在渲染层绘制，模板化后页数自适应）
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: Self.pageSize))
        let pdfData = renderer.pdfData { ctx in
            for (index, page) in pages.enumerated() {
                ctx.beginPage()
                page.draw(in: ctx.cgContext, pageSize: Self.pageSize)
                if page.showsPageNumber {
                    page.drawPageNumber(index + 1, total: pages.count, context: ctx.cgContext)
                }
            }
        }

        // 2. PDFKit 组装 + 页数校验（防御：渲染与页面数组不一致）
        guard let document = PDFDocument(data: pdfData), document.pageCount == pages.count else {
            throw MediaKitError.renderFailed
        }

        // 3. 落盘 Documents/MediaKits/（与 DraftPost 图片同模式：沙盒内管理）
        let fileManager = FileManager.default
        let docsDir = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let kitDir = docsDir.appendingPathComponent("MediaKits", isDirectory: true)
        try fileManager.createDirectory(at: kitDir, withIntermediateDirectories: true)

        let dateStr = Self.fileDateFormatter.string(from: data.generatedAt)
        let filename = "\(data.account.username)_mediakit_\(dateStr).pdf"
        let url = kitDir.appendingPathComponent(filename)
        try document.dataRepresentation()?.write(to: url, options: .atomic)

        return url
    }

    private static let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return f
    }()
}

// MARK: - 页面构建

/// 页面组装：按模板组合页面，再按数据可用性裁剪（无帖子 → 跳过内容页；全空 → 封面 + 指标占位）
protocol MediaKitPageBuilding: Sendable {
    func buildPages(data: MediaKitData, template: MediaKitTemplate) -> [MediaKitPageDrawing]
}

struct MediaKitPageBuilder: MediaKitPageBuilding {
    func buildPages(data: MediaKitData, template: MediaKitTemplate) -> [MediaKitPageDrawing] {
        switch template {
        case .minimal:
            return buildMinimal(data: data)
        case .professional, .creative:
            return buildFull(data: data, template: template)
        }
    }

    /// 极简模板：封面 + 核心指标 + 结语（固定 3 页）
    private func buildMinimal(data: MediaKitData) -> [MediaKitPageDrawing] {
        [
            MediaKitCoverPage(data: data, template: .minimal),
            MediaKitOverviewPage(data: data, template: .minimal),
            MediaKitFooterPage(data: data),
        ]
    }

    /// 完整模板（professional / creative）：封面 + 指标 + 增长 + 内容 + 互动 + 趋势柱状 + 趋势统计 ×2 + 建议 + 结语
    private func buildFull(data: MediaKitData, template: MediaKitTemplate) -> [MediaKitPageDrawing] {
        var pages: [MediaKitPageDrawing] = [
            MediaKitCoverPage(data: data, template: template),
            MediaKitOverviewPage(data: data, template: template),
        ]

        if !data.weeklyGrowth.isEmpty {
            pages.append(MediaKitGrowthPage(data: data, template: template))
        }
        if !data.topPosts.isEmpty {
            pages.append(MediaKitContentPage(data: data, template: template))
        }
        if hasEngagementSeries(data) {
            pages.append(MediaKitEngagementPage(data: data, template: template))
        }
        if !data.weeklySeries.isEmpty {
            pages.append(MediaKitTrendBarsPage(data: data, template: template))
        }
        if !data.trendSeries.isEmpty {
            pages.append(MediaKitTrendStatsPage(data: data, page: .first))
            pages.append(MediaKitTrendStatsPage(data: data, page: .second))
        }
        if !data.actionCards.isEmpty {
            pages.append(MediaKitDecisionsPage(data: data, template: template))
        }
        pages.append(MediaKitFooterPage(data: data))

        return pages
    }

    private func hasEngagementSeries(_ data: MediaKitData) -> Bool {
        !data.avgLikesSeries.isEmpty
            || !data.avgCommentsSeries.isEmpty
            || !data.engagementSeries.isEmpty
    }
}
