//
//  APIClientResolver.swift
//  Follower
//
//  API 客户端分派器 — 全局唯一分派点：所有需要 Instagram API 的服务
//  （SyncEngine / CommentService / GeoDistributionService 等）都必须经由它拿 client。
//
//  契约：哨兵 token/Users/zaneliao/Documents/github/Follower/Follower/Services/Mock/MockFollowerListGenerator.swift（mock:// 前缀）→ mockClient；其余（真实 token）→ realClient。
//  安全：真实 token 由 Meta 颁发（IGAA…/EAAB… 字母数字），格式上不可能含 "mock://" 前缀，
//        因此真实账号永远不会落到 mockClient — 测试数据只能进测试账号。
//

import Foundation

/// 按 token 值分派 API 客户端（不依赖数据库字段，判断依据是不可伪造的 token 本身）
struct APIClientResolver: Sendable {
    let realClient: InstagramAPIClientProtocol
    let mockClient: InstagramAPIClientProtocol

    /// 分派：mock 哨兵 token → mock；其余 → real
    func client(for token: String) -> InstagramAPIClientProtocol {
        MockInstagramAPIClient.isMockToken(token) ? mockClient : realClient
    }
}
