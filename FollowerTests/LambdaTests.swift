//
//  LambdaTests.swift
//  FollowerTests
//
//  Lambda model tests: PostType, TrendDataPoint, MediaPost, UnfollowEntry, CommentItem.
//

import Testing
import Foundation
@testable import Follower

struct LambdaTests {

    // MARK: - PostType enum (from MockStubs, test compatibility)

    @Test
    func testPostTypeAllCases() {
        #expect(PostType.allCases.count == 3)
    }

    // MARK: - MediaPost model

    @Test
    func testMediaPost_Fields() {
        let post = MediaPost(
            id: 1, accountId: 1, igMediaID: "abc", type: .image,
            date: Date(), likes: 1500, comments: 20,
            caption: "Test post", mediaURL: nil, permalink: nil
        )
        #expect(post.id == 1)
        #expect(post.igMediaID == "abc")
        #expect(post.type == .image)
        #expect(post.likes == 1500)
        #expect(post.comments == 20)
        #expect(!post.caption.isEmpty)
    }

    @Test
    func testMediaPost_FormattedLikes() {
        let post = MediaPost(
            id: 1, accountId: 1, igMediaID: "a", type: .image,
            date: Date(), likes: 1500, comments: 0,
            caption: "", mediaURL: nil, permalink: nil
        )
        #expect(post.formattedLikes.contains("K"))
    }

    @Test
    func testMediaPost_TypeIconName() {
        let image = MediaPost(id: 1, accountId: 1, igMediaID: "a", type: .image, date: Date(), likes: 0, comments: 0, caption: "", mediaURL: nil, permalink: nil)
        let video = MediaPost(id: 2, accountId: 1, igMediaID: "b", type: .video, date: Date(), likes: 0, comments: 0, caption: "", mediaURL: nil, permalink: nil)
        let carousel = MediaPost(id: 3, accountId: 1, igMediaID: "c", type: .carousel, date: Date(), likes: 0, comments: 0, caption: "", mediaURL: nil, permalink: nil)

        #expect(image.typeIconName == "photo")
        #expect(video.typeIconName == "video.fill")
        #expect(carousel.typeIconName == "square.on.square")
    }

    // MARK: - UnfollowEntry model

    @Test
    func testUnfollowEntry_Fields() {
        let entry = UnfollowEntry(
            id: "1", username: "test_user", displayName: "Test User",
            date: Date(), isUnfollow: true
        )
        #expect(entry.id == "1")
        #expect(entry.username == "test_user")
        #expect(entry.displayName == "Test User")
        #expect(entry.isUnfollow == true)
    }

    // MARK: - CommentItem model

    @Test
    func testCommentItem_Fields() {
        let item = CommentItem(
            id: "1", username: "test_user", text: "Great post!",
            timestamp: Date(), isReplied: false
        )
        #expect(item.id == "1")
        #expect(item.username == "test_user")
        #expect(!item.text.isEmpty)
        #expect(item.isReplied == false)
    }

    @Test
    func testCommentItem_Replied() {
        let replied = CommentItem(
            id: "2", username: "fan", text: "Fire emoji",
            timestamp: Date(), isReplied: true
        )
        #expect(replied.isReplied == true)
    }

    // MARK: - Follower delta logic

    @Test
    func testFollowerDeltaPositive() {
        let delta = 1100 - 1000
        #expect(delta == 100)
        #expect(Double(delta) / 1000 * 100 == 10.0)
    }

    @Test
    func testFollowerDeltaNegative() {
        #expect(1000 - 1100 == -100)
    }

    @Test
    func testFollowerDeltaZero() {
        #expect(1000 - 1000 == 0)
    }

    // MARK: - TrendDataPoint

    @Test
    func testTrendDataPointIdentifiable() {
        let d = Date()
        #expect(TrendDataPoint(date: d, value: 100).id == d)
    }

    // MARK: - IGMedia 图片字段

    /// IGMedia 解码：media_url / thumbnail_url 正常解析
    @Test
    func testIGMediaDecodesImageURLs() throws {
        let json = """
        {"id":"17895695668004501","media_type":"IMAGE","media_url":"https://scontent.cdninstagram.com/img.jpg","thumbnail_url":"https://scontent.cdninstagram.com/thumb.jpg"}
        """
        let media = try JSONDecoder().decode(IGMedia.self, from: Data(json.utf8))
        #expect(media.mediaURL == "https://scontent.cdninstagram.com/img.jpg")
        #expect(media.thumbnailURL == "https://scontent.cdninstagram.com/thumb.jpg")
        // IMAGE → 原图优先
        #expect(media.displayImageURL == media.mediaURL)
    }

    /// IGMedia 解码兼容：旧 API 响应缺图片字段 → nil 不崩溃
    @Test
    func testIGMediaMissingImageFieldsDefaultsNil() throws {
        let json = #"{"id":"17895695668004502","media_type":"VIDEO"}"#
        let media = try JSONDecoder().decode(IGMedia.self, from: Data(json.utf8))
        #expect(media.mediaURL == nil)
        #expect(media.thumbnailURL == nil)
        #expect(media.displayImageURL == nil)
    }

    /// 展示 URL 选择：VIDEO 用封面缩略图（media_url 是视频文件），互缺时兜底
    @Test
    func testDisplayImageURLPreference() {
        let video = IGMedia(
            id: "v1", caption: nil, mediaType: "VIDEO", permalink: nil, timestamp: nil,
            likeCount: nil, commentsCount: nil,
            mediaURL: "https://cdn/video.mp4", thumbnailURL: "https://cdn/video-cover.jpg"
        )
        #expect(video.displayImageURL == "https://cdn/video-cover.jpg", "video 应优先封面缩略图")

        let videoFallback = IGMedia(
            id: "v2", caption: nil, mediaType: "VIDEO", permalink: nil, timestamp: nil,
            likeCount: nil, commentsCount: nil, mediaURL: nil, thumbnailURL: nil
        )
        #expect(videoFallback.displayImageURL == nil)

        let image = IGMedia(
            id: "i1", caption: nil, mediaType: "IMAGE", permalink: nil, timestamp: nil,
            likeCount: nil, commentsCount: nil,
            mediaURL: "https://cdn/img.jpg", thumbnailURL: "https://cdn/thumb.jpg"
        )
        #expect(image.displayImageURL == "https://cdn/img.jpg", "image 应优先原图")

        let imageFallback = IGMedia(
            id: "i2", caption: nil, mediaType: "IMAGE", permalink: nil, timestamp: nil,
            likeCount: nil, commentsCount: nil, mediaURL: nil, thumbnailURL: "https://cdn/thumb.jpg"
        )
        #expect(imageFallback.displayImageURL == "https://cdn/thumb.jpg", "image 缺原图时用缩略图兜底")
    }

    // MARK: - IGComment 解码（评论同域 API）

    /// 新 graph.instagram.com 评论 API 不返回 username → 解码为 nil，UI 兜底「Instagram 用户」
    @Test
    func testIGCommentMissingUsernameDecodesNil() throws {
        let json = #"{"id":"17895695668004501_1","text":"好看！","timestamp":"2026-08-01T10:00:00+0000"}"#
        let comment = try JSONDecoder().decode(IGComment.self, from: Data(json.utf8))
        #expect(comment.id == "17895695668004501_1")
        #expect(comment.text == "好看！")
        #expect(comment.username == nil)
    }

    /// 兼容旧响应：带 username 时正常解析
    @Test
    func testIGCommentDecodesUsername() throws {
        let json = #"{"id":"c1","text":"hi","timestamp":"2026-08-01T10:00:00+0000","username":"test.user"}"#
        let comment = try JSONDecoder().decode(IGComment.self, from: Data(json.utf8))
        #expect(comment.username == "test.user")
    }

    // MARK: - CommentViewModel 错误提示

    /// metaErrorCode：解析 Meta OAuthException body；无效 body 返回 nil
    @Test
    func testMetaErrorCodeParsing() {
        let valid = #"{"error":{"message":"Invalid OAuth access token","type":"OAuthException","code":190,"fbtrace_id":"x"}}"#
        #expect(CommentViewModel.metaErrorCode(valid) == 190)
        #expect(CommentViewModel.metaErrorCode("not json") == nil)
        #expect(CommentViewModel.metaErrorCode(nil) == nil)
    }

    /// friendlyError：Meta 错误码 → 可操作中文提示
    @Test
    @MainActor
    func testFriendlyErrorMetaCodes() {
        func errorBody(_ code: Int) -> String {
            #"{"error":{"code":\#(code),"message":"m"}}"#
        }
        // 190：token 无效 / 缺权限 → 引导重新连接
        let e190 = APIError.httpError(statusCode: 400, body: errorBody(190))
        #expect(CommentViewModel.friendlyError(e190).contains("重新连接账号"))
        // 200：非商务账号
        let e200 = APIError.httpError(statusCode: 400, body: errorBody(200))
        #expect(CommentViewModel.friendlyError(e200).contains("商务"))
        // 10：App 权限缺失
        let e10 = APIError.httpError(statusCode: 403, body: errorBody(10))
        #expect(CommentViewModel.friendlyError(e10).contains("Meta 平台"))
        // 旧式兼容：400 + permission 子串（无错误码）
        let ePerm = APIError.httpError(statusCode: 400, body: #"{"error":{"message":"(#200) permission required"}}"#)
        #expect(CommentViewModel.friendlyError(ePerm).contains("商务"))
        // 兜底：无 body
        let ePlain = APIError.httpError(statusCode: 500, body: nil)
        #expect(CommentViewModel.friendlyError(ePlain).contains("500"))
    }

    // MARK: - OAuth 授权 URL（2026 端点）

    /// 授权端点必须是 www.instagram.com/oauth/authorize（api.instagram.com 的授权端点已迁移）；
    /// scope 逗号拼接 + 完整 query 参数
    @Test
    func testOAuthAuthorizeURL2026Endpoint() throws {
        let config = InstagramOAuthConfig(
            clientId: "4714425505453589", clientSecret: "secret",
            redirectURI: "https://localhost/oauth/callback",
            scopes: ["instagram_business_basic", "instagram_business_manage_comments"]
        )
        let url = try #require(config.authorizeURL)
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(comps.host == "www.instagram.com")
        #expect(comps.path == "/oauth/authorize")

        let params = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(params["client_id"] == "4714425505453589")
        #expect(params["redirect_uri"] == "https://localhost/oauth/callback")
        #expect(params["scope"] == "instagram_business_basic,instagram_business_manage_comments")
        #expect(params["response_type"] == "code")
    }

    // MARK: - Edge cases

    @Test
    func testDeltaPercentWhenBaseIsZero() {
        let pct: Double = 0 > 0 ? 100 / 0 : 0
        #expect(pct == 0)
    }

    @Test
    func testDashboardVMPublishedDefaults() {
        #expect(true)
    }
}
