# ADR-003：UI主题与性能策略

## 状态

已采纳

---

## 背景

产品希望使用 Liquid Glass 风格。

同时：

- 支持旧设备
- 保持流畅性

---

## 决策

实现统一组件系统：

- Apple Native Theme
- Instagram Theme
- Liquid Glass Presentation Layer

---

## 规则

- 主题不能影响业务逻辑
- Liquid Glass 可以关闭
- 图表与列表必须懒加载

---

## 收益

- UI 与业务逻辑解耦
- 主题切换成本低
- 可随时降级保证性能

---

## 风险控制

性能不足时：

直接关闭 Liquid Glass

而不是修改组件结构。