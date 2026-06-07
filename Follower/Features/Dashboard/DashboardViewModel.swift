//
//  DashboardViewModel.swift
//  Follower
//
//  Lambda: Hero 粉丝 + 次要指标 + 帖子列表 + Premium insights。

import Foundation
import SwiftUI
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    private let snapshotRepo: SnapshotRepositoryProtocol
    private let accountRepo: AccountRepositoryProtocol
    private let syncEngine: SyncEngineProtocol

    // MARK: - Published

    @Published var latestSnapshot: Snapshot?
    @Published var accounts: [Account] = []
    @Published var selectedAccountId: Int64?
    @Published var isLoading: Bool = false
    @Published var isSyncing: Bool = false
    @Published var errorMessage: String?

    // Hero
    @Published var followerDelta: Int = 0
    @Published var followerDeltaPercent: Double = 0
    @Published var sparklineData: [Double] = []

    // Secondary
    @Published var engagementDelta: Double = 0
    @Published var reachDelta: Int = 0
    @Published var postsDelta: Int = 0

    // Post list
    @Published var recentPosts: [MockPost] = []

    // Premium
    @Published var unfollowList: [MockFollower] = []
    @Published var bestPostingTime: String = ""
    @Published var contentTip: String = ""
    @Published var predictedFollowers: Int = 0

    init(snapshotRepo: SnapshotRepositoryProtocol, accountRepo: AccountRepositoryProtocol, syncEngine: SyncEngineProtocol) {
        self.snapshotRepo = snapshotRepo
        self.accountRepo = accountRepo
        self.syncEngine = syncEngine
    }

    func loadAccounts() async {
        do {
            accounts = try await accountRepo.fetchAll()
            if selectedAccountId == nil { selectedAccountId = accounts.first?.id }
            await loadAllData()
        } catch { errorMessage = error.localizedDescription }
    }

    func loadAllData() async {
        guard let accountId = selectedAccountId else { return }
        isLoading = true; defer { isLoading = false }
        do {
            latestSnapshot = try await snapshotRepo.latest(accountId: accountId)
            await computeDeltas(accountId: accountId)
            await loadPosts()
            await loadPremiumInsights()
        } catch { errorMessage = error.localizedDescription }
    }

    func sync() async {
        guard let accountId = selectedAccountId else { return }
        isSyncing = true; defer { isSyncing = false }
        do {
            _ = try await syncEngine.sync(accountId: accountId)
            await loadAllData()
        } catch { errorMessage = error.localizedDescription }
    }

    func selectAccount(_ id: Int64) { selectedAccountId = id; Task { await loadAllData() } }

    // MARK: - Private

    private func computeDeltas(accountId: Int64) async {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        guard let snapshots = try? await snapshotRepo.fetch(accountId: accountId, from: weekAgo, to: now),
              let current = latestSnapshot else { return }

        sparklineData = snapshots.map { Double($0.followersCount) }

        if let first = snapshots.first {
            followerDelta = current.followersCount - first.followersCount
            followerDeltaPercent = first.followersCount > 0 ? Double(followerDelta) / Double(first.followersCount) * 100 : 0
            engagementDelta = current.engagementRate - first.engagementRate
            reachDelta = current.totalViews - first.totalViews
            postsDelta = current.mediaCount - first.mediaCount
        }
    }

    private func loadPosts() async {
        recentPosts = MockPostGenerator().generate(count: 5)
    }

    private func loadPremiumInsights() async {
        unfollowList = MockFollowerListGenerator().generateUnfollows(count: 4)
        bestPostingTime = ["Wed 7PM", "Mon 8PM", "Sat 11AM", "Fri 6PM"].randomElement()!
        contentTip = ["Carousel posts get 2.3x more engagement", "Videos under 30s perform best", "Post 3-5 times per week for optimal growth"].randomElement()!
        predictedFollowers = (latestSnapshot?.followersCount ?? 1000) + Int.random(in: 50...500)
    }
}
