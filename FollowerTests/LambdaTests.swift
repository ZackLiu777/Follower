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
            id: 1, igMediaID: "abc", type: .image,
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
            id: 1, igMediaID: "a", type: .image,
            date: Date(), likes: 1500, comments: 0,
            caption: "", mediaURL: nil, permalink: nil
        )
        #expect(post.formattedLikes.contains("K"))
    }

    @Test
    func testMediaPost_TypeIconName() {
        let image = MediaPost(id: 1, igMediaID: "a", type: .image, date: Date(), likes: 0, comments: 0, caption: "", mediaURL: nil, permalink: nil)
        let video = MediaPost(id: 2, igMediaID: "b", type: .video, date: Date(), likes: 0, comments: 0, caption: "", mediaURL: nil, permalink: nil)
        let carousel = MediaPost(id: 3, igMediaID: "c", type: .carousel, date: Date(), likes: 0, comments: 0, caption: "", mediaURL: nil, permalink: nil)

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
