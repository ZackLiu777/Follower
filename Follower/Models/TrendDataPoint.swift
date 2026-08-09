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
    /// 图表值 — Double 是图表层（TrendChart）的输入契约，数据层保证传入的永远是整数语义值
    let value: Double

    /// Int 便捷初始化：Metric.value（整数）直接映射到图表值，避免 View 层做类型转换
    init(date: Date, value: Int) {
        self.date = date
        self.value = Double(value)
    }

    init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}
