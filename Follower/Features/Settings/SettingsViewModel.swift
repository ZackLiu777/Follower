//
//  SettingsViewModel.swift
//  Follower
//
//  设置页 ViewModel。

import Foundation
import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Dependencies

    private let trialManager: TrialManagerProtocol
    private let exportService: ExportServiceProtocol
    private let accountRepo: AccountRepositoryProtocol
    private let premiumFeatureRepo: PremiumFeatureRepositoryProtocol

    // MARK: - Published State

    @Published var isTrialActive: Bool = false
    @Published var trialRemainingTime: String = ""
    @Published var currentTheme: AppTheme = .appleNative
    @Published var selectedAccountId: Int64?
    @Published var accounts: [Account] = []

    @Published var exportURL: URL?
    @Published var isExporting: Bool = false
    @Published var exportFormat: ExportFormat = .json

    @Published var premiumFeatures: [PremiumFeature] = []

    @Published var showDeleteConfirmation: Bool = false
    @Published var showPrivacyPolicy: Bool = false

    @Published var errorMessage: String?

    // MARK: - Init

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

    func updateTheme(_ theme: AppTheme) {
        currentTheme = theme
    }

    // MARK: - Export

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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private func formatRemainingTime(_ time: TimeInterval?) -> String {
        guard let time = time, time > 0 else { return loc(L10n.Premium.trialEnded) }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: loc(L10n.Premium.trialRemaining), minutes, seconds)
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case json
    case csv

    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        }
    }
}
