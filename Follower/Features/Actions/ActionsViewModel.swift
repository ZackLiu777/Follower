//
//  ActionsViewModel.swift
//  Follower
//
//  Created by Zane Liao on 2026/7/2.
//
//  数据与UI交互，也就是业务逻辑

import Foundation
import SwiftUI
import Combine

@MainActor
@Observable
final class ActionsViewModel {
    /// 账户数据仓库
    private let accountRepo: AccountRepositoryProtocol
    
    
    init (
        accountRepo: AccountRepositoryProtocol
    ) {
        self.accountRepo = accountRepo
    }
    
    
}
