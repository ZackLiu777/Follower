# 测试策略

## 目标

在保证应用响应速度的前提下，验证：

- 业务逻辑正确性
- 数据持久化正确性
- UI 稳定性
- 数据迁移安全性

---

## 测试层级

### 单元测试（Unit Tests）

用于验证：

- 确定性计算函数
- Repository 查询逻辑
- API 数据映射逻辑
- 聚合逻辑（Aggregation）
- 导出格式化逻辑

---

### 集成测试（Integration Tests）

用于验证：

- Sync → Ingestion → Event → Snapshot → Metric 整体流程
- 数据库迁移
- 本地导出与导入
- Premium 功能开关
- 首次启动与试用逻辑

---

### UI 测试（UI Tests）

用于验证：

- App 启动
- 登录流程
- Tab 切换
- 主题切换
- Dashboard 渲染
- 空状态与离线状态

---

## 测试要求

- 所有确定性函数必须有单元测试
- 所有 Repository 查询与聚合逻辑必须测试
- 所有 Schema 修改必须验证 Migration
- 复杂功能没有测试不得视为完成

---

## 覆盖率建议

- 核心业务计算：高覆盖率
- Repository 与 Aggregation：严格覆盖
- UI：重点覆盖核心路径