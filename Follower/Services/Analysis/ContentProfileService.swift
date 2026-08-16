//
//  ContentProfileService.swift
//  Follower
//
//  Premium: 内容档案（Phi+）— 从真实 MediaPost 挖掘"你的爆款公式"。
//  纯函数、确定性：
//  - 互动档位：爆款（≥ 2×平均）/ 平庸 / 低互动（≤ 0.3×平均）
//  - 类型表现矩阵（每类型的平均互动 / 发帖占比 / 档位分布）
//  - 爆款共同特征（dominant 类型 / 星期 / 小时 / caption 长度区间）
//  - Top 5 最佳帖子
//  - caption 长度与互动的相关性（长/短分组均值对比）
//

import Foundation

// MARK: - 结果模型

/// 互动档位
enum ContentTier: String, Sendable {
    case viral, average, low
}

/// 单类型表现
struct ContentTypeBand: Sendable {
    let type: ContentType
    /// 平均互动（likes + comments）
    let avgEngagement: Double
    /// 发帖数
    let postCount: Int
    /// 发帖占比（0-1）
    let share: Double
    /// 爆款数
    let viralCount: Int
}

/// 爆款共同特征（爆款 ≥ 2 篇时给出）
struct ViralFormula: Sendable {
    /// dominant 内容类型（nil = 无显著）
    let dominantType: ContentType?
    /// dominant 星期（1=周日...7=周六；nil = 无显著）
    let dominantWeekday: Int?
    /// dominant 小时（nil = 无显著）
    let dominantHour: Int?
    /// 爆款 caption 平均长度（字符）
    let avgCaptionLength: Double
    /// 非爆款 caption 平均长度（对比）
    let avgCaptionLengthOthers: Double
}

/// Top 帖子
struct TopContentPost: Sendable {
    let type: ContentType
    let date: Date
    let engagement: Int
    let likes: Int
    let comments: Int
    let caption: String
}

/// 内容档案结果
struct ContentProfileResult: Sendable {
    let totalPosts: Int
    let averageEngagement: Double
    /// 类型表现（有帖子的类型）
    let typeBands: [ContentTypeBand]
    /// 档位分布
    let viralCount: Int
    let averageCount: Int
    let lowCount: Int
    /// 爆款公式（爆款 < 2 篇时 nil）
    let viralFormula: ViralFormula?
    /// Top 5 帖子（互动降序）
    let topPosts: [TopContentPost]
    /// caption 长度相关性（长 vs 短分组，nil = 帖子 < 4）
    let captionInsight: (longAvg: Double, shortAvg: Double)?
}

// MARK: - Service

/// 内容档案服务 — 确定性纯计算
final class ContentProfileService: Sendable {

    /// 档位阈值：爆款 ≥ 2×平均；低互动 ≤ 0.3×平均
    static let viralMultiplier = 2.0
    static let lowMultiplier = 0.3

    func analyze(from posts: [MediaPost]) async -> ContentProfileResult {
        guard !posts.isEmpty else { return emptyResult() }

        let engagements = posts.map { Double($0.likes + $0.comments) }
        let mean = engagements.reduce(0, +) / Double(posts.count)

        // 档位
        var viral: [MediaPost] = []
        var average: [MediaPost] = []
        var low: [MediaPost] = []
        for post in posts {
            let e = Double(post.likes + post.comments)
            if e >= mean * Self.viralMultiplier { viral.append(post) }
            else if e <= mean * Self.lowMultiplier { low.append(post) }
            else { average.append(post) }
        }

        // 类型表现
        var bands: [ContentType: (count: Int, sum: Double, viral: Int)] = [:]
        for post in posts {
            guard let type = ContentType(mediaType: post.type) else { continue }
            var b = bands[type] ?? (0, 0, 0)
            b.count += 1
            b.sum += Double(post.likes + post.comments)
            b.viral += viral.contains(where: { $0.igMediaID == post.igMediaID }) ? 1 : 0
            bands[type] = b
        }
        let typeBands = bands.map { type, b in
            ContentTypeBand(
                type: type,
                avgEngagement: b.sum / Double(max(1, b.count)),
                postCount: b.count,
                share: Double(b.count) / Double(posts.count),
                viralCount: b.viral
            )
        }.sorted { $0.avgEngagement > $1.avgEngagement }

        // 爆款公式
        let formula: ViralFormula?
        if viral.count >= 2 {
            let cal = Calendar.current
            let typeCounts = viral.compactMap { ContentType(mediaType: $0.type) }
            let dominantType = typeCounts.max { a, b in
                typeCounts.filter { $0 == a }.count < typeCounts.filter { $0 == b }.count
            }
            let weekdayCounts = Dictionary(grouping: viral) { cal.component(.weekday, from: $0.date) }
            let dominantWeekday = weekdayCounts.max { $0.value.count < $1.value.count }?.key
            let hourCounts = Dictionary(grouping: viral) { cal.component(.hour, from: $0.date) }
            let dominantHour = hourCounts.max { $0.value.count < $1.value.count }?.key
            let viralCaptionAvg = viral.map { Double($0.caption.count) }.reduce(0, +) / Double(viral.count)
            let others = average + low
            let othersAvg = others.isEmpty ? 0 : others.map { Double($0.caption.count) }.reduce(0, +) / Double(others.count)
            formula = ViralFormula(
                dominantType: dominantType,
                dominantWeekday: dominantWeekday,
                dominantHour: dominantHour,
                avgCaptionLength: viralCaptionAvg,
                avgCaptionLengthOthers: othersAvg
            )
        } else {
            formula = nil
        }

        // Top 5
        let topPosts = posts.sorted { $0.likes + $0.comments > $1.likes + $1.comments }
            .prefix(5)
            .map { post in
                TopContentPost(
                    type: ContentType(mediaType: post.type) ?? .photo,
                    date: post.date,
                    engagement: post.likes + post.comments,
                    likes: post.likes,
                    comments: post.comments,
                    caption: post.caption
                )
            }

        // caption 相关性：长（>中位数）vs 短（≤中位数）分组均值
        let captionInsight: (Double, Double)?
        if posts.count >= 4 {
            let sortedByCaption = posts.sorted { $0.caption.count < $1.caption.count }
            let mid = sortedByCaption.count / 2
            let shortGroup = sortedByCaption.prefix(mid)
            let longGroup = sortedByCaption.suffix(mid)
            let shortAvg = shortGroup.map { Double($0.likes + $0.comments) }.reduce(0, +) / Double(shortGroup.count)
            let longAvg = longGroup.map { Double($0.likes + $0.comments) }.reduce(0, +) / Double(longGroup.count)
            captionInsight = (longAvg, shortAvg)
        } else {
            captionInsight = nil
        }

        return ContentProfileResult(
            totalPosts: posts.count,
            averageEngagement: mean,
            typeBands: typeBands,
            viralCount: viral.count,
            averageCount: average.count,
            lowCount: low.count,
            viralFormula: formula,
            topPosts: Array(topPosts),
            captionInsight: captionInsight
        )
    }

    private func emptyResult() -> ContentProfileResult {
        ContentProfileResult(
            totalPosts: 0, averageEngagement: 0, typeBands: [],
            viralCount: 0, averageCount: 0, lowCount: 0,
            viralFormula: nil, topPosts: [], captionInsight: nil
        )
    }
}
