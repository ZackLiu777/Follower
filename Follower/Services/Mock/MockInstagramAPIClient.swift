//
//  MockInstagramAPIClient.swift
//  Follower
//
//  测试账号专用 Mock API Client — 实现 InstagramAPIClientProtocol。
//  仅当 accessToken == sentinelToken（哨兵值）时被 APIClientResolver 选中；
//  真实 OAuth/Token 账号的 token 由 Meta 颁发，字符集不可能含 "mock://" 前缀，
//  因此绝不会落到本实现（安全方向：测试数据只能进测试账号）。
//
//  数据覆盖（730 天，确定性生成，同 seed 同结果）：
//  - follower_count / reach / views 日频序列（含下跌段 → 取关列表、爆发日 → 决策故事）
//  - 25 条媒体（三类型：含爆款 / 零互动边界用例）
//  - ~50 条评论绑定前 10 个媒体（评论数与媒体 comments_count 对齐）
//  - audience_country lifetime breakdown（8 国，百分比和 = 100 → 地域分布）
//

import Foundation

// MARK: - MockInstagramAPIClient

final class MockInstagramAPIClient: InstagramAPIClientProtocol, @unchecked Sendable {

    /// 哨兵 token：测试账号存入 Keychain 的假 token。
    /// 真实 Instagram token（IGAA…/EAAB…）为字母数字，不可能含 "mock://" 前缀。
    static let sentinelToken = "mock://token"

    /// 判定 token 是否属于测试账号（APIClientResolver 的唯一分派依据）
    static func isMockToken(_ token: String) -> Bool {
        token.hasPrefix("mock://")
    }

    /// 默认固定种子 — 所有测试账号数据形态一致，可复现可断言
    static let defaultSeed: UInt64 = 42

    /// 媒体总数（与 IGUser.mediaCount 保持一致）
    static let mediaCount = 25
    /// 评论覆盖的媒体数（前 N 条媒体带评论）
    static let commentedMediaCount = 10

    private let dataset: MockDataset
    /// reply 递增计数器（跨线程保护）
    private let lock = NSLock()
    private var replyCounter: Int = 0

    init(seed: UInt64 = MockInstagramAPIClient.defaultSeed) {
        self.dataset = MockDataset(seed: seed)
    }

    // MARK: - InstagramAPIClientProtocol

    func fetchProfile(accessToken: String) async throws -> IGUser {
        dataset.user
    }

    func fetchInsights(accessToken: String, metrics: [String], period: String) async throws -> [IGInsightValue] {
        // 地域分布（Premium GeoDetailView）：audience_country → lifetime breakdown 形态
        if metrics.contains("audience_country") {
            return [dataset.countryInsight]
        }
        // 请求的指标序列 + 附加互动明细（likes/comments/shares 供趋势聚合）。
        // 真实 API 不请求这三个指标（避免 400），mock 忽略请求列表直接附加 ——
        // SyncEngine.buildTrend 对未知指标缺省为 0，真实路径行为不变。
        var result: [IGInsightValue] = []
        for metric in metrics {
            switch metric {
            case "follower_count": result.append(dataset.followerInsight)
            case "reach": result.append(dataset.reachInsight)
            case "views": result.append(dataset.viewsInsight)
            default: break
            }
        }
        result.append(contentsOf: [
            dataset.likesInsight, dataset.commentsInsight, dataset.sharesInsight,
        ])
        return result
    }

    func fetchMedia(accessToken: String, limit: Int) async throws -> [IGMedia] {
        Array(dataset.media.prefix(limit))
    }

    func fetchComments(accessToken: String, mediaID: String, limit: Int) async throws -> [IGComment] {
        Array((dataset.commentsByMedia[mediaID] ?? []).prefix(limit))
    }

    func replyComment(accessToken: String, mediaID: String, message: String) async throws -> String {
        lock.lock(); defer { lock.unlock() }
        replyCounter += 1
        // 与真实 Instagram 评论 ID 同形态的 18 位数字
        return "1789569566800\(replyCounter)"
    }

    func deleteComment(accessToken: String, commentID: String) async throws {
        // 本地 mock：删除总是成功
    }
}

// MARK: - MockDataset

/// 确定性生成的全部 Mock 数据（一次生成，只读复用）
private struct MockDataset {
    let user: IGUser
    /// 730 天日频序列（升序）：(日期, 粉丝数, reach, views)
    let dailySeries: [(date: Date, followers: Int, reach: Int, views: Int)]
    let media: [IGMedia]
    let commentsByMedia: [String: [IGComment]]
    let followerInsight: IGInsightValue
    let reachInsight: IGInsightValue
    let viewsInsight: IGInsightValue
    /// 互动明细日频序列（likes/comments/shares）— 历史互动图表数据源
    let likesInsight: IGInsightValue
    let commentsInsight: IGInsightValue
    let sharesInsight: IGInsightValue
    let countryInsight: IGInsightValue

    init(seed: UInt64) {
        var rng = SeededRandom(seed: seed)

        // ═══ 1. 730 天日频序列 ═══
        let days = 730
        // 两段随机下跌（避开最后 7 天），驱动 Decision 引擎的流失故事
        let dip1Start = rng.int(in: 10...(days / 3 - 10))
        let dip1Len = rng.int(in: 2...4)
        let dip2Start = rng.int(in: (days / 3 + 10)...(days - 100))
        let dip2Len = rng.int(in: 2...4)
        // 最后 7 天固定增量模式：净变化确定为负（触发 Dashboard 取关列表 diff）
        let lastWeekPattern = [2, -25, 1, -20, -18, 0, -12]
        // 两个爆发日（90 天内、避开最后 7 天），reach ×3-5 倍
        let boost1 = rng.int(in: 0...(days - 90))
        let boost2 = rng.int(in: (days - 80)...(days - 8))

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let startOfToday = cal.startOfDay(for: Date())
        let iso = ISO8601DateFormatter()

        var followers = 8000
        var series: [(date: Date, followers: Int, reach: Int, views: Int)] = []
        series.reserveCapacity(days)
        for i in 0..<days {
            let delta: Int
            if i >= days - 7 {
                delta = lastWeekPattern[i - (days - 7)]
            } else if (dip1Start..<(dip1Start + dip1Len)).contains(i)
                        || (dip2Start..<(dip2Start + dip2Len)).contains(i) {
                delta = -rng.int(in: 20...40)
            } else {
                delta = rng.int(in: 0...10)
            }
            followers = max(5000, followers + delta)

            var reach = rng.int(in: 500...3000)
            if i == boost1 || i == boost2 {
                reach = rng.int(in: 9000...15000) // 爆发日
            }
            let views = Int(Double(reach) * rng.double(in: 0.5..<1.5))
            let date = cal.date(byAdding: .day, value: i - (days - 1), to: startOfToday)!
            series.append((date: date, followers: followers, reach: reach, views: views))
        }

        let datePoints = series.map { (date: $0.date, value: $0.followers) }
        let reachPoints = series.map { (date: $0.date, value: $0.reach) }
        let viewsPoints = series.map { (date: $0.date, value: $0.views) }
        func toInsight(name: String, points: [(date: Date, value: Int)]) -> IGInsightValue {
            IGInsightValue(
                name: name, period: "day",
                values: points.map { IGInsightDataPoint(value: Double($0.value), endTime: iso.string(from: $0.date)) },
                totalValue: nil
            )
        }
        followerInsight = toInsight(name: "follower_count", points: datePoints)
        reachInsight = toInsight(name: "reach", points: reachPoints)
        viewsInsight = toInsight(name: "views", points: viewsPoints)

        // 互动日频序列：与 reach 成正比（互动率 2-6%），
        // 用 rng 副本生成 —— 不消耗主 rng 状态，媒体/评论等既有数据形态与断言值不变
        var insightRng = rng
        let likePoints = series.map { (date: $0.date, value: Int(Double($0.reach) * insightRng.double(in: 0.02..<0.06))) }
        let commentPoints = likePoints.map { (date: $0.date, value: Int(Double($0.value) * insightRng.double(in: 0.03..<0.08))) }
        let sharePoints = likePoints.map { (date: $0.date, value: Int(Double($0.value) * insightRng.double(in: 0.01..<0.04))) }
        likesInsight = toInsight(name: "likes", points: likePoints)
        commentsInsight = toInsight(name: "comments", points: commentPoints)
        sharesInsight = toInsight(name: "shares", points: sharePoints)

        // ═══ 2. 用户资料（一致性：粉丝 = 序列末值，媒体数 = mediaCount）═══
        user = IGUser(
            id: "17841400000000000",
            username: "test.user",
            name: "Test User",
            followersCount: series.last!.followers,
            followsCount: 420,
            mediaCount: MockInstagramAPIClient.mediaCount,
            accountType: "BUSINESS" // BUSINESS → 解锁评论管理入口
        )

        // ═══ 3. 25 条媒体 ═══
        let captions = [
            "今天的日落真的绝了 🌅", "新品上线！快来评论区告诉我你的想法",
            "早八咖啡，续命成功 ☕", "幕后花絮大放送 🎬",
            "夏日限定的快乐，抓紧啦", "周末短途旅行 vlog 预告",
            "新造型 get，风格大变样", "工作到深夜的日常 💪",
            "自我疗愈的一天 🧘", "旅行日记：第一站",
            "健身打卡第 30 天", "深夜碎碎念，睡不着的来集合",
            "OOTD：今天走慵懒风", "美食探店：巷子里的宝藏小店",
            "录音室的一天，新歌筹备中 🎵", "雨天在家，安静地画画",
            "宠物的迷惑行为大赏", "读书分享：最近在看的书",
            "citywalk 随手拍", "和粉丝互动的问答时间",
            "出差路上的风景", "咖啡拉花练习成果",
            "周末市集淘到的好物", "晨跑看到的日出",
            "总结一下这周的小确幸 ✨",
        ]
        // 每条媒体的评论数：前 10 条 2-8 条（评论区有内容），后 15 条 0 条
        var commentCounts: [Int] = []
        commentCounts.reserveCapacity(MockInstagramAPIClient.mediaCount)
        for i in 0..<MockInstagramAPIClient.mediaCount {
            commentCounts.append(i < MockInstagramAPIClient.commentedMediaCount ? rng.int(in: 2...8) : 0)
        }

        var generatedMedia: [IGMedia] = []
        generatedMedia.reserveCapacity(MockInstagramAPIClient.mediaCount)
        for i in 0..<MockInstagramAPIClient.mediaCount {
            let mediaType: String
            switch i % 3 {
            case 0: mediaType = "CAROUSEL_ALBUM"
            case 1: mediaType = "VIDEO"
            default: mediaType = "IMAGE"
            }
            // 时间分布：前 15 条在最近 90 天（列表页/仪表盘展示），后 10 条散布更早
            let dayOffset = i < 15 ? rng.int(in: (days - 90)...(days - 1)) : rng.int(in: 120...(days - 100))
            let date = cal.date(byAdding: .day, value: -dayOffset, to: startOfToday)!

            // 互动分布：i==3 爆款（×10+），i==11/12 零互动边界
            let likes: Int
            if i == 3 {
                likes = 20000 + rng.int(in: 0...5000)
            } else if i == 11 || i == 12 {
                likes = rng.int(in: 0...2)
            } else {
                likes = rng.int(in: 50...5000)
            }

            generatedMedia.append(IGMedia(
                id: "178956956680045\(String(format: "%02d", i))",
                caption: captions[i],
                mediaType: mediaType,
                permalink: "https://www.instagram.com/p/MOCK_\(i)/",
                timestamp: iso.string(from: date),
                likeCount: likes,
                commentsCount: commentCounts[i]
            ))
        }
        media = generatedMedia

        // ═══ 4. 评论：绑定前 10 个媒体，数量与 comments_count 对齐 ═══
        let commentTexts = [
            "太好看啦！", "求教程！", "这也太绝了吧 🔥", "每天必刷你的更新",
            "学到了，谢谢分享", "支持支持！", "这个滤镜是什么？", "哈哈哈哈笑死",
            "羡慕了羡慕了", "已经转发给朋友了", "什么时候出下一期？",
            "拍得真好，构图很舒服", "nice post!", "Love this ❤️", "Keep it up!",
        ]
        let commentUsernames = [
            "emma.wilson", "alex.martinez", "sophia.chen", "james.lee", "olivia.park",
            "noah.johnson", "ava.garcia", "liam.brown", "mia.davis", "lucas.taylor",
        ]
        var commentsDict: [String: [IGComment]] = [:]
        for i in 0..<MockInstagramAPIClient.commentedMediaCount {
            let mediaID = media[i].id
            let mediaDate = iso.date(from: media[i].timestamp!) ?? startOfToday
            var comments: [IGComment] = []
            comments.reserveCapacity(commentCounts[i])
            for j in 0..<commentCounts[i] {
                let commentDate = cal.date(byAdding: .day, value: rng.int(in: 0...5), to: mediaDate)!
                comments.append(IGComment(
                    id: "1789569566800\(45 + i * 10 + j)",
                    text: rng.pick(commentTexts),
                    timestamp: iso.string(from: commentDate),
                    username: rng.pick(commentUsernames)
                ))
            }
            commentsDict[mediaID] = comments
        }
        commentsByMedia = commentsDict

        // ═══ 5. 地域分布（lifetime breakdown，百分比和 = 100）═══
        countryInsight = IGInsightValue(
            name: "audience_country", period: "lifetime",
            values: nil,
            totalValue: IGInsightTotalValue(breakdowns: [
                IGInsightBreakdown(dimensionValues: ["US"], value: 35),
                IGInsightBreakdown(dimensionValues: ["CN"], value: 18),
                IGInsightBreakdown(dimensionValues: ["JP"], value: 12),
                IGInsightBreakdown(dimensionValues: ["KR"], value: 10),
                IGInsightBreakdown(dimensionValues: ["GB"], value: 8),
                IGInsightBreakdown(dimensionValues: ["DE"], value: 7),
                IGInsightBreakdown(dimensionValues: ["FR"], value: 5),
                IGInsightBreakdown(dimensionValues: ["BR"], value: 5),
            ])
        )

        // ═══ 6. 内部一致性校验（防御：生成错误尽早暴露）═══
        assert(series.last!.followers == user.followersCount)
        assert(media.count == MockInstagramAPIClient.mediaCount)
        // 互动序列必须有非零值（历史互动图表数据源）
        assert((likesInsight.values ?? []).contains { ($0.value ?? 0) > 0 })
        let breakdownSum = countryInsight.totalValue?.breakdowns?
            .compactMap { $0.value }
            .reduce(0, +) ?? 0
        assert(breakdownSum == 100)
        for (id, comments) in commentsByMedia {
            assert(media.contains { $0.id == id })
            assert(comments.count > 0)
        }
        dailySeries = series
    }
}
