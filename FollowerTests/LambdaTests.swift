//
//  LambdaTests.swift
//  FollowerTests

import XCTest
@testable import Follower

final class LambdaTests: XCTestCase {

    // MARK: - MockPostGenerator

    func testMockPostGeneratorCount() {
        let gen = MockPostGenerator()
        XCTAssertEqual(gen.generate(count: 5).count, 5)
        XCTAssertEqual(gen.generate(count: 20).count, 20)
    }

    func testMockPostHasNonEmptyFields() {
        let posts = MockPostGenerator().generate(count: 3)
        XCTAssertEqual(posts.count, 3)
        for post in posts {
            XCTAssertFalse(post.id.isEmpty)
            XCTAssertFalse(post.caption.isEmpty)
        }
    }

    func testMockPostsSortedNewestFirst() {
        let posts = MockPostGenerator().generate(count: 30)
        for i in 0..<posts.count - 1 {
            XCTAssertGreaterThanOrEqual(posts[i].date, posts[i + 1].date)
        }
    }

    // MARK: - MockFollowerListGenerator

    func testMockFollowerListCount() {
        let gen = MockFollowerListGenerator()
        XCTAssertEqual(gen.generateUnfollows(count: 4).count, 4)
    }

    func testMockFollowerListAreUnfollows() {
        let list = MockFollowerListGenerator().generateUnfollows(count: 5)
        for f in list { XCTAssertTrue(f.isUnfollow) }
    }

    // MARK: - Delta logic

    func testFollowerDeltaPositive() {
        let first = 1000; let latest = 1100
        XCTAssertEqual(latest - first, 100)
        XCTAssertEqual(Double(latest - first) / Double(first) * 100, 10.0, accuracy: 0.01)
    }

    func testFollowerDeltaNegative() {
        XCTAssertEqual(1000 - 1100, -100)
    }

    // MARK: - TrendDataPoint

    func testTrendDataPointIdentifiable() {
        let date = Date()
        let point = TrendDataPoint(date: date, value: 100)
        XCTAssertEqual(point.id, date)
    }
}
