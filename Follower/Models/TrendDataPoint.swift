//
//  TrendDataPoint.swift
//  Follower
//
//  趋势数据点模型。每个数据点代表一个时间槽内的聚合值。
//

import Foundation

/// 趋势图中的单个数据点，Identifiable 以支持 SwiftUI ForEach
struct TrendDataPoint: Identifiable {
    /// id 即日期，保证同一时间槽只有一个数据点
    var id: Date { date }
    let date: Date
    let value: Double
}
