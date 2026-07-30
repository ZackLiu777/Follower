//
//  SettingsViewModel.swift
//  Follower
//
//  设置页 ViewModel。

import Foundation
import SwiftUI
import Combine

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

    // MARK: - Premium Unlock (dev mode: one-tap unlock all)

    /// 一键解锁所有 Premium 功能（开发模式）
    func unlockAllPremium() async {
        for key in PremiumFeatureKey.allCases {
            try? await premiumFeatureRepo.setEnabled(true, expiresAt: nil, for: key)
        }
        do {
            premiumFeatures = try await premiumFeatureRepo.fetchAll()
        } catch {}
        // 通知所有 PremiumGate 重新检查
        NotificationCenter.default.post(name: .premiumUnlocked, object: nil)
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

    // MARK: - Private

    /// 将 TimeInterval 格式化为 "X 分 Y 秒" 的剩余时间字符串
    private func formatRemainingTime(_ time: TimeInterval?) -> String {
        guard let time = time, time > 0 else { return loc(L10n.Premium.trialEnded) }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: loc(L10n.Premium.trialRemaining), minutes, seconds)
    }
}
