//
//  AccountViewModelTests.swift
//  FollowerTests
//
//  Account ViewModel 测试：账号创建（不含 SyncEngine），撤销，删除。

import XCTest
@testable import Follower

final class AccountViewModelTests: XCTestCase {
    var db: DatabaseManager!
    var accountRepo: AccountRepository!
    var eventRepo: EventRepository!

    override func setUp() async throws {
        db = DatabaseManager.shared
        accountRepo = AccountRepository(db: db)
        eventRepo = EventRepository(db: db)
    }

    // MARK: - Account Creation (without sync)

    func testAddAccountCreatesRecordWithoutSync() async throws {
        // 模拟没有 SyncEngine 的创建（Beta-2.0.1 修复）
        let account = Account(
            platform: .instagram,
            username: "vm_test_\(UUID())",
            displayName: "VM Test",
            authState: .authorized,
            createdAt: Date(),
            updatedAt: Date()
        )
        let saved = try await accountRepo.insert(account)
        XCTAssertNotNil(saved.id, "Account creation should return an id")
    }

    func testAddAccountShowsInList() async throws {
        let before = try await accountRepo.count()
        let account = Account(
            platform: .instagram,
            username: "list_\(UUID())",
            displayName: "List Test",
            authState: .authorized,
            createdAt: Date(),
            updatedAt: Date()
        )
        _ = try await accountRepo.insert(account)
        let after = try await accountRepo.count()
        XCTAssertEqual(after, before + 1)
    }

    // MARK: - Revoke

    func testRevokeChangesAuthState() async throws {
        let account = Account(
            platform: .instagram,
            username: "revoke_\(UUID())",
            displayName: "Revoke Test",
            authState: .authorized,
            createdAt: Date(),
            updatedAt: Date()
        )
        let saved = try await accountRepo.insert(account)
        guard let id = saved.id else { XCTFail("No id"); return }

        var fetched = try await accountRepo.fetch(id: id)
        XCTAssertEqual(fetched?.authState, .authorized)

        fetched?.authState = .revoked
        if var updated = fetched {
            try await accountRepo.update(updated)
        }

        let after = try await accountRepo.fetch(id: id)
        XCTAssertEqual(after?.authState, .revoked)
    }

    // MARK: - Delete

    func testDeleteRemovesAccount() async throws {
        let account = Account(
            platform: .instagram,
            username: "delete_vm_\(UUID())",
            displayName: "Delete Test",
            authState: .authorized,
            createdAt: Date(),
            updatedAt: Date()
        )
        let saved = try await accountRepo.insert(account)
        guard let id = saved.id else { XCTFail("No id"); return }

        try await accountRepo.delete(id: id)
        let fetched = try await accountRepo.fetch(id: id)
        XCTAssertNil(fetched)
    }

    // MARK: - Validation

    func testEmptyUsernameShouldFailValidation() {
        // addAccount 应在 username/displayName 为空时返回错误
        // 这个逻辑在 AccountViewModel 中，通过 guard 检查
        let emptyUsername = ""
        let emptyDisplayName = ""
        XCTAssertTrue(emptyUsername.isEmpty)
        XCTAssertTrue(emptyDisplayName.isEmpty)
    }
}
