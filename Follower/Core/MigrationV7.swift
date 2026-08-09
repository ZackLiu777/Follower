//
//  MigrationV7.swift
//  Follower
//
//  v7 迁移：Metric 数值整数化。
//  旧版本 Metric.value 为 Double：
//    - engagementTrend 存 0~1 比率（如 0.0543）
//    - 计数类指标存浮点（历史平均产生的 8250.5 等）
//  新版本统一整数语义：
//    - engagementTrend → 万分比整数（0.0543 → 543）
//    - 计数类 → ROUND 四舍五入取整
//

import Foundation
import GRDB

// MARK: - MigrationV7

enum MigrationV7 {
    /// 执行 v7 迁移：换算历史 Metric 数值为整数语义
    /// - 幂等：迁移只注册运行一次；两个 UPDATE 均为确定性换算
    nonisolated static func run(in db: Database) throws {
        // 1. engagementTrend：旧比率（0 < value < 1）→ 万分比整数
        //    条件排除已是万分比的旧值（> 1），防止重复换算
        try db.execute(sql: """
            UPDATE metric
            SET value = CAST(ROUND(value * 10000) AS INTEGER)
            WHERE metricType = 'engagementTrend' AND value > 0 AND value < 1
            """)

        // 2. 其余计数类：ROUND 取整（8250.5 → 8251）
        try db.execute(sql: """
            UPDATE metric
            SET value = CAST(ROUND(value) AS INTEGER)
            WHERE metricType != 'engagementTrend'
            """)
    }
}
