//
//  RoutingTokenProvider.swift
//  Follower
//
//  Token 路由 Provider — 测试账号 token 不落 Keychain。
//
//  背景：测试账号（isTest=true）的哨兵 token（mock://token）写入 Keychain 可能失败
//  （模拟器/无 entitlement），导致账号已创建但 token 丢失 → 同步走"无 token"分支
//  → 全零数据 + 账号堆积。
//
//  方案：按账号语义分派——
//  - 测试账号：getToken 一律返回哨兵（不查 Keychain，旧版坏账号自动恢复）；
//    storeToken 为 no-op（哨兵 token 无需持久化）。
//  - 真实账号：原样转发 Keychain。
//
//  安全：分派依据是 Account.isTest（DB 语义）+ 哨兵 token 值，真实 token（IGAA…/EAAB…）
//  永远只走 Keychain 分支，行为与 TokenProvider 完全一致。
//

import Foundation

// MARK: - RoutingTokenProvider

final actor RoutingTokenProvider: TokenProviderProtocol {
    /// Keychain 存储（真实账号专用）
    private let keychain: TokenProviderProtocol
    /// 读取账号语义（isTest 判定）
    private let accountRepo: AccountRepositoryProtocol

    init(keychain: TokenProviderProtocol, accountRepo: AccountRepositoryProtocol) {
        self.keychain = keychain
        self.accountRepo = accountRepo
    }

    // MARK: - TokenProviderProtocol

    /// 测试账号的哨兵 token 不落 Keychain（内存语义，创建流程永不因 Keychain 失败）
    func storeToken(accountId: Int64, accessToken: String) async throws {
        guard !MockInstagramAPIClient.isMockToken(accessToken) else { return }
        try await keychain.storeToken(accountId: accountId, accessToken: accessToken)
    }

    /// 测试账号 → 哨兵 token（即使 Keychain 中无值；兼容历史坏账号）；
    /// 真实账号 → 转发 Keychain
    func getToken(accountId: Int64) async throws -> String {
        if let account = try? await accountRepo.fetch(id: accountId), account.isTest {
            return MockInstagramAPIClient.sentinelToken
        }
        return try await keychain.getToken(accountId: accountId)
    }

    /// 删除转发 Keychain（测试账号本无条目，delete 幂等无副作用）
    func deleteToken(accountId: Int64) async throws {
        try await keychain.deleteToken(accountId: accountId)
    }
}
