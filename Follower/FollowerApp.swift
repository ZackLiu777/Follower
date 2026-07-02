//
//  FollowerApp.swift
//  Follower
//
//  Lambda-2: isDark 驱动 preferredColorScheme。
//

import SwiftUI

/// App 入口 — 初始化 AppState，驱动主题与 Splash
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
                LinearGradient(
                    colors: [appState.currentTheme.theme.backgroundGradientStart,
                             appState.currentTheme.theme.backgroundGradientEnd],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                ContentView()
                    .environmentObject(appState)
                    .task { await appState.container.trialManager.startTrialIfNeeded() }

                if showSplash && !skipSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.6)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                }
            }
            .preferredColorScheme(appState.currentTheme.theme.isDark ? .dark : .light)
        }
    }
}
