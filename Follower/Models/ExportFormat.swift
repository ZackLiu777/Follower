//
//  ExportFormat.swift
//  Follower
//
//  数据导出格式模型。
//

import Foundation

/// 导出格式枚举：JSON / CSV
enum ExportFormat: String, CaseIterable {
    case json
    case csv

    /// 用户可见的格式名称
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        }
    }
}
