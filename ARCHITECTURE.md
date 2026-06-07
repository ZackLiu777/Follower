# ARCHITECTURE.md

## 1. 系统目标

本项目是一款本地优先的 Instagram数据跟踪与分析应用，核心目标是：

- 保持用户数据本地存储。
- 提供基础统计、历史趋势和数据导出。
- 为 Premium 分析能力预留扩展接口。
- 在 iPhone 上保持高响应性和低复杂度 UI。

## 2. 技术栈

- UI：SwiftUI
- 架构：MVVM
- 持久化：GRDB + SQLite
- 序列化：Codable
- 导出：JSON 为主，CSV / Excel 作为扩展
- 并发：Swift Concurrency
- 测试：XCTest

## 3. 分层结构

### 3.1 SwiftUI Views
职责：

- 展示数据
- 响应用户输入
- 绑定 ViewModel 状态

禁止：

- 直接访问数据库
- 直接调用 API
- 在 View 中计算复杂指标

### 3.2 ViewModels
职责：

- 维护页面状态
- 编排 Repository 和 Service
- 暴露给 View 所需的数据模型
- 处理轻量的展示逻辑

禁止：

- 直接操作数据库细节
- 做大规模 I/O
- 承担复杂聚合计算

### 3.3 Repository Layer
职责：

- 作为唯一数据访问入口
- 封装 GRDB 查询与写入
- 管理缓存
- 提供结构化查询方法

Repository 是业务代码与数据库之间的边界层。

### 3.4 Sync Engine
职责：

- 管理外部账号同步流程
- 处理授权状态
- 控制同步频率
- 执行增量同步与重试

### 3.5 Ingestion Service
职责：

- 接收 API 返回数据
- 将外部 JSON 映射为内部模型
- 生成 Event 记录

### 3.6 Aggregation Service
职责：

- 由 Event 生成 Snapshot
- 由 Snapshot 生成 Metric
- 处理后台增量计算
- 避免在主线程执行重计算

## 4. 数据模型分层

### 4.1 Event
原始记录层，表示“发生了什么”。

特性：

- append-only
- 可追溯
- 用于回放与重建状态

### 4.2 Snapshot
状态层，表示“当前或某个时间点是什么状态”。

特性：

- 面向 UI 查询
- 支持 upsert
- 控制查询成本

### 4.3 Metric
分析层，表示“状态变化意味着什么”。

特性：

- 派生数据
- 后台计算
- 面向 Premium 与分析图表

## 5. 数据流

```text
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
    ↓
Repository
    ↓
ViewModel
    ↓
SwiftUI Views


## Recommended Directory Structure

当前项目采用 Feature-first 组织方式。

初期只要求遵守顶层结构：

Follower/
├── App/
├── Features/
├── Core/
├── Services/
├── Repository/
├── Models/
├── Resources/
├── Tests/
└── UITests/

说明：

- 不要求提前创建所有目录。
- 功能出现时再创建对应 Feature。
- 不要为了目录完整性创建大量空文件。
- 当一个 Feature 超过 3 个文件时，可创建子目录。