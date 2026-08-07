# ADR-002：同步与聚合管线

## 状态

已采纳

---

## 背景

需要：

- 从外部 API 获取数据
- 保持本地状态一致
- 不阻塞 UI

---

## 决策

采用统一管线：

External API
↓
Sync Engine
↓
Ingestion Service
↓
Event
↓
Aggregation Service
↓
Snapshot
↓
Metric

---

## 规则

- Event 为 Append-Only
- Snapshot 支持 Upsert
- Metric 为派生数据
- 聚合逻辑异步执行
- UI 不执行重计算

---

## 收益

- 职责清晰
- 容易测试
- 容易扩展

---

## 成本

需要：

- 后台触发机制
- 重试机制
- 同步状态管理