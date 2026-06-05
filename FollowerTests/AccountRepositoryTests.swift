//
//  AccountRepositoryTests.swift
//  Follower

import XCTest
@testable import Follower

final class AccountRepositoryTests: XCTestCase {
    var repository: AccountRepository!

    override func setUp() async throws {
        repository = AccountRepository(db: DatabaseManager.shared)
    }

    func testInsertAndFetch() async throws {
        let account = Account(
            platform: .instagram,
            username: "test_user",
            displayName: "Test User",
            authState: .authorized,
            createdAt: Date(),
            updatedAt: Date()
        )

        let saved = try await repository.insert(account)
        XCTAssertNotNil(saved.id)

        let fetched = try await repository.fetch(id: saved.id!)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.username, "test_user")
    }

    func testCount() async throws {
        let initial = try await repository.count()
        let account = Account(platform: .instagram, username: "ct", displayName: "C", authState: .authorized, createdAt: Date(), updatedAt: Date())
        _ = try await repository.insert(account)
        let after = try await repository.count()
        XCTAssertEqual(after, initial + 1)
    }

    func testDelete() async throws {
        let account = Account(platform: .instagram, username: "del", displayName: "D", authState: .authorized, createdAt: Date(), updatedAt: Date())
        let saved = try await repository.insert(account)
        guard let id = saved.id else { return XCTFail("No id") }
        try await repository.delete(id: id)
        let fetched = try await repository.fetch(id: id)
        XCTAssertNil(fetched)
    }
}
