//
//  SettingsViewModel.swift
//  Follower
//
//  设置页 ViewModel。

import Foundation
import SwiftUI
import Combine

// MARK: - PremiumMasterState（状态机）

/// 全部 Premium 功能开关的聚合状态
enum PremiumMasterState: Equatable, Sendable {
    case allUnlocked   // 所有功能已解锁（Toggle ON）
    case partial       // 部分解锁（Toggle OFF，处于中间态）
    case allLocked     // 所有功能已锁定（Toggle OFF）
}

/// 设置页 ViewModel — 试用 / 导出 / Premium / 删除数据
@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - Dependencies

    private let trialManager: TrialManagerProtocol
    private let exportService: ExportServiceProtocol
    private let accountRepo: AccountRepositoryProtocol
    private let premiumFeatureRepo: PremiumFeatureRepositoryProtocol

    // MARK: - Published State

     var isTrialActive: Bool = false
     var trialRemainingTime: String = ""
     var currentTheme: AppTheme = .instagram
     var selectedAccountId: Int64?
     var accounts: [Account] = []

     var exportURL: URL?
     var isExporting: Bool = false
     var exportFormat: ExportFormat = .json

     var premiumFeatures: [PremiumFeature] = []

     /// Master 开关聚合状态（状态机）：全部解锁 / 部分 / 全部锁定
     var masterState: PremiumMasterState = .allLocked

     /// Toggle 显示状态 — 仅当所有功能都解锁时为 ON
     var masterUnlocked: Bool { masterState == .allUnlocked }

     var showDeleteConfirmation: Bool = false
     var showPrivacyPolicy: Bool = false

     var errorMessage: String?

    // MARK: - Init

    /// 注入依赖：TrialManager / ExportService / AccountRepo / PremiumRepo
    init(
        trialManager: TrialManagerProtocol,
        exportService: ExportServiceProtocol,
        accountRepo: AccountRepositoryProtocol,
        premiumFeatureRepo: PremiumFeatureRepositoryProtocol
    ) {
        self.trialManager = trialManager
        self.exportService = exportService
        self.accountRepo = accountRepo
        self.premiumFeatureRepo = premiumFeatureRepo
    }

    // MARK: - Public

    /// 加载试用状态、账号列表、Premium 功能开关
    func loadSettings() async {
        // Trial
        await trialManager.checkTrialStatus()
        isTrialActive = await trialManager.isTrialActive()
        trialRemainingTime = formatRemainingTime(await trialManager.remainingTime())

        // Accounts
        do {
            accounts = try await accountRepo.fetchAll()
            if selectedAccountId == nil {
                selectedAccountId = accounts.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        // Premium features
        do {
            premiumFeatures = try await premiumFeatureRepo.fetchAll()
        } catch {
            // 静默处理
        }
        refreshMasterState()
    }

    /// 切换主题风格
    func updateTheme(_ theme: AppTheme) {
        currentTheme = theme
    }

    // MARK: - Export

    /// 根据 exportFormat 导出数据为 JSON 或 CSV 文件
    func exportData() async {
        guard let accountId = selectedAccountId else {
            errorMessage = loc(L10n.Account.noAccountSelected)
            return
        }
        isExporting = true
        defer { isExporting = false }

        do {
            switch exportFormat {
            case .json:
                exportURL = try await exportService.exportAsJSON(accountId: accountId)
            case .csv:
                exportURL = try await exportService.exportAsCSV(accountId: accountId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Premium Master Toggle（状态机）

    /// Master 开关：ON → 全部解锁，OFF → 全部锁定
    /// 状态转移：toggle → 写库所有 key → 重载 → 聚合状态 → 通知 PremiumGate 同步
    func setMasterUnlocked(_ enabled: Bool) async {
        for key in PremiumFeatureKey.allCases {
            try? await premiumFeatureRepo.setEnabled(enabled, expiresAt: nil, for: key)
        }
        premiumFeatures = (try? await premiumFeatureRepo.fetchAll()) ?? []
        refreshMasterState()
        // 通知所有 PremiumGate / AppState 重新检查
        NotificationCenter.default.post(name: .premiumUnlocked, object: nil)
    }

    /// 状态机转移：根据全部 key 的实际启用情况重算聚合状态
    private func refreshMasterState() {
        guard !premiumFeatures.isEmpty else {
            masterState = .allLocked
            return
        }
        let enabledCount = premiumFeatures.filter(\.enabled).count
        if enabledCount == premiumFeatures.count {
            masterState = .allUnlocked
        } else if enabledCount == 0 {
            masterState = .allLocked
        } else {
            masterState = .partial
        }
    }

    // MARK: - Delete Data

    /// 删除指定账号的本地数据（隐私权利）
    func deleteLocalData(accountId: Int64) async {
        do {
            try await accountRepo.delete(id: accountId)
            accounts = try await accountRepo.fetchAll()
            if selectedAccountId == accountId {
                selectedAccountId = accounts.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 一次性删除所有账号及其关联数据
    func deleteAllAccounts() async {
        do {
            let all = try await accountRepo.fetchAll()
            for account in all {
                if let id = account.id {
                    try await accountRepo.delete(id: id)
                }
            }
            accounts = []
            selectedAccountId = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    /// 将 TimeInterval 格式化为 "X 分 Y 秒" 的剩余时间字符串
    private func formatRemainingTime(_ time: TimeInterval?) -> String {
        guard let time = time, time > 0 else { return loc(L10n.Premium.trialEnded) }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: loc(L10n.Premium.trialRemaining), minutes, seconds)
    }
}
