# 数据模型概览

## 核心实体

---

## Account

表示一个已连接的社交媒体账号。

建议字段：

- id
- platform
- username
- displayName
- createdAt
- updatedAt
- authState

---

## Event

表示一次原始观测记录或同步记录。

建议字段：

- id
- accountId
- eventType
- payload
- source
- observedAt
- createdAt

---

## Snapshot

表示某一时间点的状态快照。

建议字段：

- id
- accountId
- followersCount
- followingCount
- mediaCount
- engagementRate
- observedAt
- createdAt

---

## Metric

表示派生分析指标。

建议字段：

- id
- accountId
- metricType
- value
- window
- observedAt
- createdAt

---

## PremiumFeature

表示 Premium 功能开关。

建议字段：

- id
- key
- enabled
- expiresAt
- createdAt

---

## 数据模型规则

- Event 为 Append-Only
- Snapshot 为面向查询的状态数据
- Metric 为可重新计算的派生数据
- Account 与 PremiumFeature 属于辅助实体