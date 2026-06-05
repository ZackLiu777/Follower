//
//  FollowerApp.swift
//  Follower
//
//  App 入口。
//  初始化 GRDB 数据库，注入全局主题与依赖。
//  试用初始化延后到首个 View 出现后，避免阻塞启动。

import SwiftUI

@main
struct FollowerApp: App {
    @StateObject private var appState: AppState

    init() {
        let dbManager = DatabaseManager.shared
        _appState = StateObject(wrappedValue: AppState(databaseManager: dbManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .withTheme(from: appState)
                .task {
                    // 延后初始化试用，确保数据库和 UI 都已就绪
                    await appState.container.trialManager.startTrialIfNeeded()
                }
        }
    }
}
