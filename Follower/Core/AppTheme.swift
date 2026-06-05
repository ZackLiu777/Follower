//
//  AppTheme.swift
//  Follower
//
//  主题枚举：Apple Native / Instagram Style
//  UI 主题不能影响业务逻辑；Liquid Glass 仅作为视觉层。
//

import Foundation

enum AppTheme: String, CaseIterable {
    case appleNative
    case instagram

    var displayName: String {
        switch self {
        case .appleNative: return "Apple Native"
        case .instagram: return "Instagram"
        }
    }
}
