# Gamma Spec — v0.03

## 版本目标

Gamma 版本的核心目标是**把 Premium 从"权限旗帜"变成"实际功能"**。

Alpha 解决了"能跑、能存、能聚合"。Beta 解决了"像产品、有语言、有主题"。Gamma 解决的是"Premium 到底买了什么"。

---

## 1. 设计约束

1. **不破坏 Alpha/Beta 的功能**。所有基础功能继续可用，Premium 只是在基础之上增强。
2. **Premium 数据与基础数据隔离**。Premium 产出的分析结果全部存入 Metric 表（新增 MetricType 枚举值），不污染 Snapshot 和 Event。
3. **Premium 计算必须异步**。不允许在主线程做统计推断、回归分析或导出重型文件。
4. **Premium 功能受 PremiumGate 控制**。未解锁时展示锁定状态，解锁后展示实际数据。解锁状态已由 `PremiumFeatureRepository` 管理，Gamma 只需要对接。
5. **遵循现有架构边界**：View → ViewModel → Service → Repository → Database。不做跨层调用。
6. **仅面向 Instagram**。删除 TikTok 相关所有 UI 和文案（`Platform` 枚举保留但 UI 隐藏）。

---

## 2. 移除 TikTok 支持

### 2.1 范围

TikTok 相关的基础设施（`Platform.tiktok`、对应的 API DTO 字段）**保留在数据模型中**——它们不占用运行时资源，且保留未来重新启用的可能性。Gamma 只做**UI 层面**的移除。

### 2.2 具体操作

- [ ] `AccountView`：平台选择器只显示 Instagram
- [ ] `AccountViewModel`：创建账号时默认 `Platform.instagram`，移除平台选择交互
- [ ] 所有 L10n key 中 TikTok 相关文案保持不变（`account.tiktok` key 保留）
- [ ] Dashboard 账号选取器中不再显示 TikTok 图标

---

## 3. Premium 功能实现路线

### Phase 1：CSV 导出增强 + Excel 导出

**优先级**：最高。这是最直接可感知的 Premium 价值。

- [ ] `ExportService` 增加 `exportAsExcel()` 方法（使用 CSV 格式保存为 `.xlsx` 或 `.csv` 带 BOM，保证 Excel 兼容）
- [ ] JSON/CSV 导出**已经是基础功能**（免费），Excel 导出为 **Premium 独占**
- [ ] Settings 导出区域：当 `csvExport` 或 `excelExport` Premium key 启用时，显示额外格式选项
- [ ] 导出按钮增加 Premium 锁图标，点击时检查 `premiumFeatureRepo.isEnabled(key:)`

**实现细节**：
```swift
// ExportService 新增
func exportAsExcel(accountId: Int64) async throws -> URL {
    // 生成 .csv 文件，带 UTF-8 BOM，Excel 可直接打开
    // 复杂格式（合并单元格、图表）留给未来版本
}
```

### Phase 2：长期趋势对比

**优先级**：高。充分利用已有的 Metric 数据。

- [ ] 新增 `longTermTrendComparison` 指标类型到 `MetricType`
- [ ] 新增 `ComparisonService`：对比两个时间周期（如「本月 vs 上月」「今年 Q1 vs 去年 Q1」）
- [ ] 在 Trends 页增加「对比」模式（Premium 解锁后显示）
- [ ] 对比结果显示变化率、变化方向和绝对值差异

**数据存储**：对比结果存为新的 Metric 行（`metricType: .longTermTrendComparison`），按周/月窗口聚合。**不修改 Snapshot 表**。

**实现细节**：
```swift
// 新增 ComparisonService (Services/Analysis/)
func compare(
    accountId: Int64,
    currentPeriod: DateInterval,
    previousPeriod: DateInterval,
    metricType: MetricType
) async throws -> ComparisonResult {
    let current = try await metricRepo.fetch(...)
    let previous = try await metricRepo.fetch(...)
    return ComparisonResult(change: ...)
}
```

### Phase 3：互动质量评分

**优先级**：高。用户能直接理解的价值。

- [ ] 新增 `engagementQualityScore` 到 `MetricType`
- [ ] 评分模型（在 `AggregationService` 或新建 `ScoringService` 中）：
  - 关键指标：互动率（likes + comments + shares）/ views
  - 加权计算：评论权重 > 分享权重 > 点赞权重
  - 输出 0-100 分
- [ ] Dashboard 增加「互动质量」卡片（Premium 解锁后显示）
- [ ] Trends 增加「质量评分趋势」指标

**数据存储**：每天生成一条 `engagementQualityScore` Metric，按天/周/月聚合。

**注意**：评分逻辑必须是确定性函数（方便单元测试），不依赖外部数据。

### Phase 4：活跃度分析

**优先级**：中。

- [ ] 新增 `activityAnalysis` 到 `MetricType`
- [ ] 分析维度：
  - 日活跃度：基于 `Event` 的 `observedAt` 分布，统计有数据的天数占比
  - 周活跃模式：一周中哪几天最活跃
  - 发布频率：`mediaCount` 的变化率
- [ ] 结果展示：Dashboard 增加「活跃度」卡片，Trends 增加「活跃模式」指标

### Phase 5：留存/流失分析

**优先级**：中。

- [ ] 新增 `retentionAnalysis` 和 `churnAnalysis` 到 `MetricType`
- [ ] 留存率计算：基于 `Snapshot.followersCount` 的逐日变化
  - 净增长率 = (新关注 - 取关) / 总粉丝
  - 留存率 = 1 - 流失率
- [ ] 流失预警：连续 N 天粉丝净减少 → 标记为流失风险
- [ ] 结果存为 Metric（天/周窗口）

### Phase 6：趋势预测

**优先级**：低。需要更多数据才有意义。

- [ ] 新增 `followerGrowthPrediction` 和 `trendPrediction` 到 `MetricType`
- [ ] 预测引擎（新建 `PredictionService`）：
  - 简单移动平均（SMA）：最近 7/30 天的均值 → 预测明天
  - 线性回归：基于 90 天数据拟合趋势线 → 预测 30 天
- [ ] 在 Trends 图表上叠加预测线（虚线，区分实际 vs 预测）
- [ ] 显示预测置信区间

**注意**：预测模型必须是纯本地计算，不依赖网络。

### Phase 7：地域分布

**优先级**：低（Mock 数据）。

- [ ] 新增 `geoDistribution` 到 `MetricType`
- [ ] 当前阶段使用 **Mock 数据** 展示功能框架（真实地理位置数据需要用户授权和 Instagram API 支持）
- [ ] UI：Dashboard 增加「粉丝地域分布」卡片（按国家/城市展示百分比）
- [ ] 数据结构预留：`Metric` 的 `value` 表示百分比，通过 payload JSON 存储细分数据

### Phase 8：本地 AI 分析

**优先级**：最低（技术验证阶段）。

- [ ] 新增 `localAIAnalysis` 到 `MetricType`
- [ ] 使用 Apple 的 **TabularData** + **CreateML** 框架（设备端推理）
- [ ] 功能范围（V1）：异常检测（检测粉丝数突变、互动率暴跌）+ 自然语言摘要
- [ ] 所有 AI 计算在后台 `Task.detached(priority: .background)` 中执行
- [ ] 结果展示为文字摘要卡片（如「过去一周你的互动率异常下降了 15%，可能与发布频率减少有关」）

**注意**：
- 不引入第三方 ML 库（只用 Apple 原生框架）
- 模型推理必须在 2 秒内完成（iPhone 本地约束）
- 如果 CreateML 不可用，降级为规则引擎（阈值判断）

### Phase 9：加强加密 + 多设备同步（占位）

- [ ] 研究 `GRDB` + `SQLCipher` 的可行性（数据库级加密）
- [ ] 多设备同步标记为 **Gamma 非目标**——仅在 Settings 中保留占位
- [ ] 加强加密：即使实现了，也只对 Premium 产生的 Metric 数据加密，基础数据保留明文

---

## 4. 数据隔离原则

Gamma 的每一行 Premium 代码都必须遵守：

| 规则 | 示例 |
|------|------|
| Premium 数据只写入 Metric 表 | ✅ `Metric(type: .engagementScore, value: 85)` ❌ 不在 Snapshot 加 `qualityScore` 字段 |
| Premium 计算只发生在 Service 层 | ✅ `ScoringService.calculate()` ❌ 不在 ViewModel 或 View 中计算 |
| Premium UI 通过 PremiumGate 控制 | ✅ `StatCard(...).premiumGate(feature: .engagementQualityScore)` ❌ 不在 View 中硬编码 `if isPremium` |
| 基础功能不依赖 Premium | ✅ 删除 `EngagementService` 不影响 Dashboard 基础统计 ❌ 基础功能 import Premium Service |

---

## 5. 新增文件清单

```
Services/Analysis/
├── ComparisonService.swift      # 长期趋势对比
├── ScoringService.swift         # 互动质量评分
├── ActivityAnalysisService.swift # 活跃度分析
├── RetentionAnalysisService.swift # 留存/流失分析
├── PredictionService.swift      # 趋势预测 + 增长预测
├── GeoDistributionService.swift # 地域分布（Mock）
└── AIAnalysisService.swift      # 本地 AI 分析（占位）

新增 MetricType 枚举值：
- longTermTrendComparison
- engagementQualityScore
- activityAnalysis
- retentionAnalysis
- churnAnalysis
- followerGrowthPrediction
- trendPrediction
- geoDistribution
- localAIAnalysis
```

---

## 6. UI 新增页面

- [ ] Dashboard：「互动质量」卡片（Premium）、「活跃度」卡片（Premium）、「地域分布」卡片（Premium）
- [ ] Trends：「长期对比」模式（对比两个时间段）、「预测线」叠加（虚线）、「活跃模式」热力图
- [ ] 我的 → Premium 区域：每个功能的详细说明 + 预览（如「预测下月粉丝数：1,234 → 1,456」）

---

## 7. 不变更的部分（明确排除）

Gamma **不做**以下事情：

- ❌ 不改基础功能（Dashboard 基础卡片、Trends 基础图表、导出、账号管理）
- ❌ 不改数据库 Schema（不增加新表，所有 Premium 数据存入 Metric 表）
- ❌ 不改 Repository 结构（不增加新的 Repository）
- ❌ 不引入第三方依赖（只使用 Apple 原生框架）
- ❌ 不实现真实的支付接口（一键解锁保留开发模式）
- ❌ 不添加 OAuth 或真实 API 对接

---

## 8. 完成标准

| 条件 | 标准 |
|------|------|
| Premium 功能可感知 | 解锁后 Dashboard/Trends 显示额外卡片和指标 |
| 数据隔离 | Premium 数据全部在 Metric 表中，可单独删除 |
| 异步计算 | 所有分析在后台线程，UI 不阻塞 |
| 门控正确 | 未解锁时显示锁图标，解锁后显示实际数据 |
| 不破坏基础功能 | Alpha/Beta 功能在未解锁 Premium 时完全不变 |
| TikTok 移除 | UI 中不再出现 TikTok 选项 |
| 构建通过 | `xcodebuild build` SUCCEEDED |
| 测试通过 | 新增的确定性计算函数有单元测试 |

---

## 9. Gamma 不做的（留给 Post-Gamma）

- 真实支付（IAP / StoreKit）
- 真实 Instagram API 对接
- 多设备同步的实际实现
- 自定义 Dashboard 布局
- 推送通知
- Widget

---

*Gamma 的目标不是"把 13 个功能全部完美实现"，而是"让用户解锁 Premium 后，能真切地感受到 App 多了什么能力"。*
