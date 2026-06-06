//
//  FollowerApp.swift
//  Follower
//
//  App 入口。Beta-2.0: 开屏页面 → 主界面过渡。

import SwiftUI

@main
struct FollowerApp: App {
    @StateObject private var appState: AppState
    @State private var showSplash: Bool = true

    private let skipSplash: Bool

    init() {
        let dbManager = DatabaseManager.shared
        _appState = StateObject(wrappedValue: AppState(databaseManager: dbManager))
        skipSplash = ProcessInfo.processInfo.arguments.contains("UI_TEST")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(appState)
                    .task {
                        await appState.container.trialManager.startTrialIfNeeded()
                    }

                if showSplash && !skipSplash {
                    SplashView {
                        showSplash = false
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}
