//
//  MockFollowerListGeneratorTests.swift
//  FollowerTests
//
//  Mock 取关列表生成器单元测试 — 数量、结构、用户名格式、
//  日期降序排列、唯一性。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for MockFollowerListGenerator — count, structure, ordering, uniqueness
struct MockFollowerListGeneratorTests {

    /// 默认生成 5 条取关记录
    @Test
    func testDefaultCountIsFive() {
        let list = MockFollowerListGenerator().generateUnfollows()
        #expect(list.count == 5)
    }

    /// 指定 count → 返回对应数量
    @Test
    func testGenerateSpecifiedCount() {
        let list = MockFollowerListGenerator().generateUnfollows(count: 12)
        #expect(list.count == 12)
        let zero = MockFollowerListGenerator().generateUnfollows(count: 0)
        #expect(zero.isEmpty)
    }

    /// 全部记录 isUnfollow = true（取关列表语义）
    @Test
    func testAllEntriesAreUnfollow() {
        let list = MockFollowerListGenerator().generateUnfollows(count: 8)
        #expect(list.allSatisfy { $0.isUnfollow })
    }

    /// 用户名 = 基础用户名 + 序号后缀（如 "emma.wilson0"）
    @Test
    func testUsernameHasNumericSuffix() {
        let list = MockFollowerListGenerator().generateUnfollows(count: 6)
        for f in list {
            // 基础用户名列表全部以 "<名字>.<姓氏>" 形式存在
            let base = f.username.dropLast(1)   // 去掉序号后缀
            #expect(base.contains("."), "username should be <base>\(f.username.suffix(1)) with a dot-separated base")
        }
    }

    /// id 唯一（UUID）
    @Test
    func testIDsAreUnique() {
        let list = MockFollowerListGenerator().generateUnfollows(count: 10)
        let ids = Set(list.map(\.id))
        #expect(ids.count == list.count)
    }

    /// 日期降序排列（最新在前）
    @Test
    func testSortedByDateDescending() {
        let list = MockFollowerListGenerator().generateUnfollows(count: 10)
        for i in 0..<(list.count - 1) {
            #expect(list[i].date >= list[i + 1].date)
        }
    }

    /// 显示名非空且存在头像颜色
    @Test
    func testDisplayNameAndAvatarColorPresent() {
        let list = MockFollowerListGenerator().generateUnfollows(count: 6)
        for f in list {
            #expect(!f.displayName.isEmpty)
            #expect(!f.avatarColor.isEmpty)
            #expect(f.avatarColor.hasPrefix("#"), "avatarColor should be a hex color")
        }
    }
}
