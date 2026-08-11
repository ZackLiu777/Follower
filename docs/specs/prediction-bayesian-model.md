# Spec: 粉丝预测 — 贝叶斯负二项回归模型（v0.17-alpha）

## 1. 背景与目标

现有 `PredictionService.predictLinear` 使用索引线性回归 + R²，无法表达预测不确定性，
且对增长型数据（负二项族）拟合不当。本 spec 将其替换为**贝叶斯负二项回归**：

- 输出**预测可信区间（95% ETI）**而非点估计 —— 回答「未来 30 天可能增长多少」。
- 输出 `P(增长 > X)` 概率 —— 回答「增长超过 X 的概率」。
- 纯 Swift 手写实现（无第三方依赖），与现有 GRDB/Accelerate 依赖模式一致。

## 2. 模型

### 2.1 观测模型（负二项回归）

对每天 t 的粉丝增量 y_t = max(0, followers_{t+1} − followers_t)：

```
y_t ~ NegBinomial(μ_t, φ)
log μ_t = β₀ + Σₖ βₖ·x_{t,k}
```

- 均值-离散参数化：E[y] = μ，Var[y] = μ + μ²/φ（φ 越大越接近泊松）。
- 负二项要求 y ≥ 0：负增长截断为 0（P1 决策；P3 评估取关指示特征时再处理）。
- **预测可信区间（Predictive Credible Interval）**：对未来观测的后验预测分布取等尾 95%
  分位数 —— 是可信区间而非置信区间（回答「未来增长落在该区间的概率」）。

### 2.2 特征（P1 启用 4 维，全部仅用 t 及之前数据）

| # | 名称 | 定义 |
|---|------|------|
| 0 | log_followers | log(followers_t) |
| 1 | momentum_7d | (followers_t − followers_{t−7}) / 7 |
| 2 | accel_7d | 最近 7 点最小二乘线性斜率 |
| 3 | lag_growth_1d | followers_t − followers_{t−1} |

**v0.16 删除 lag_growth_7d**：它与 momentum_7d 满足恒等式 lag_growth_7d ≡ 7 ×
momentum_7d（任何数据下严格线性相关 → 特征矩阵列秩亏 → 似然 Hessian 退化、
牛顿步病态 → Laplace fit 在真实数据上失败返回 nil）。删除后特征满秩，数值稳定。

互动 3 维（like/comment/share rate）为**预留位**：真实 API 无日频数据源，
接入后扩展 `FeatureEngine.featureCount` 即可（不改变模型结构）。

特征行构建要求点数 ≥ 9（t ≥ 7 且需 t+1 的 target）；冷启动阈值 30 行 → `nil`。

### 2.3 先验

- β₁...β₄ ~ Normal(0, 1)（正则化防过拟合），截距 β₀ 不惩罚。
- φ ~ Gamma(2, rate: 0.1)（弱信息，均值 20）。
- 参数向量 θ = [β₀..β₄, logφ]，共 6 维；logφ 参数化保证 φ > 0。

### 2.4 推断：Laplace 近似（确定性，可测）

牛顿法求 MAP（θ* = argmax logP(θ|data)）：

1. 初始值 θ₀ = [0, ..., log(5)]。
2. 梯度：**解析式**（含 digamma）；Hessian：**数值中心差分**（h=1e-4，对解析梯度差分）
   —— 避免 trigamma 推导错误风险。
3. 每步：牛顿步 Δ = (−H)⁻¹·g（对数后验全局凹，H 负定；对 A = −H 加对角
   jitter（1e-8 起 10 倍倍增，≤12 次）满足 Cholesky 正定要求）；步长减半
   回退（≤10 次）保证后验上升。
4. 收敛判定 |Δθ| < 1e-6·(1+|θ|)，最多 100 次迭代。
5. 后验近似：θ ~ N(θ*, (−H)⁻¹)；协方差对 A = −H + 1e-8·I 逐列求逆
   （solve 单位向量），结果对称化。

选择 Laplace 而非 MCMC（HMC/NUTS）：**确定性路径**——同输入必同输出，
单元测试可精确断言，无采样器收敛调试成本。P2 若需重尾后验再评估 HMC。

v0.16 数值健壮性修复（真实数据上 fit 返回 nil 的根因与兜底）：

- 根因：恒等式共线特征（见 2.2）→ 病态牛顿步 → 步长减半全部失败。
- 修复 1：删除 lag_growth_7d，特征满秩（根治）。
- 修复 2：步长减半 10 次全部不升时接受最佳有限候选（原实现 `stepLength < 1e-6`
  阈值在 10 次减半内不可达——死代码分支，牛顿步不升即整体 nil）。
- 修复 3：滚动预测协方差 Cholesky 失败 → 对角 jitter 重试（防御对称化数值误差）。

**v0.17 符号修复（fit 在真实数据上恒 nil 的最终根因）**：

- 观测：mock 90 天数据 fit 恒 nil；Hessian 对角 ≈ −107..−78（负曲率），
  jitter=1000 才"正定"；10 个减半步长的候选 logPosterior 全部有限且单调递增，
  但无一超过 theta₀ 处值 → fallback 路径整体 nil。
- 数学事实：负二项 logPDF 对 η 的二阶导 = −φμ(y+φ)/(μ+φ)² < 0 恒成立 →
  **对数后验对 θ 全局凹 → Hessian 负定**。最大化问题的牛顿步 Δ = −H⁻¹·g。
- 原实现 bug：对负定 H 直接加**正** jitter 直到 dpotrf 可分解（λ 需盖过
  |λmin(H)| ≈ 107），此时 (H+λI)⁻¹ 是正定矩阵 → Δ = (H+λI)⁻¹·(−g) ≈ **下降方向**
  → 任何步长后验都不升 → 步长回退链整体 nil。协方差求解同理：对负定 H 加
  1e-8 永远无法 dpotrf → 即使迭代收敛也必然 nil。
- 修复：牛顿步与协方差均对 **A = −H（全元素取负）** 加对角 jitter 后 solve
  —— A 正定（λ 极小时即成功），solve(A, g) = (−H)⁻¹·g 方向恒正确。
- 验证（独立诊断脚本，mock seed 42 复刻）：7 次迭代收敛，cov 正定
  （cholesky 一次成功），forecast ✓ mean=155 / median=81 / P(>0)=1.0；
  4 个数据形态消融（纯 0..10 / 带 7 天负增长 / 中间段 / 完整 mock）全部 fit ✓
  —— 证实失败与数据形态无关，纯为矩阵符号实现错误。

**v0.18–v0.20 数值健壮性修复（CI 33 个测试失败的根因）**：

- **v0.18 收敛判定**：fallback 分支此前用"最后一次减半的 stepLength"乘
  rawStep 估算变化量，而 fallback 是独立候选（实际变化远大于该值）→ 真实
  变化被低估 → 提前误判收敛。现按实际应用的参数变化判定。
- **v0.19 收敛判定移到线搜索之前**：收敛末期牛顿步（~1e-9）小于
  logPosterior 的浮点分辨率，线搜索所有候选 ≈ 当前值 → fallback 为空 →
  已收敛被误报为整体失败 → fit nil。原始步长低于阈值时直接接受并计算协方差。
- **v0.20 jitter 阶梯 scale-aware**：低 φ 区（φ ≪ μ）logφ 维曲率可为正
  （H[5,5] > 0）→ A = −H 存在**耦合负特征值**（实测 −1300 级，且截距×logφ
  子块 det < 0）——对数后验对 logφ 并非全局凹，v0.17 的"全局凹"仅对 β 成立。
  固定 1e-8 起、12 级到 1e3 的旧阶梯在 |λmin| > 1e3 时永远失败 → fit nil。
  现按 A 最大对角缩放起始 jitter（1e-12·maxDiag，≥1e-8），14 级 ×10。
- **测试数据生成器修复（TestHelpers）**：`exp(beta[0] + dot(beta, features))`
  中 dot 已含截距 → 截距被双加 → 合成数据 μ 放大 e^β0 倍（特征上百/上千，
  平滑增长期近共线 → 迭代 0 步 A 数值不定）。改为 `exp(dot(beta, features))`，
  与模型 log μ = β·x̃ 一致；测试系数相应调小（momentum 0.5 → 0.05）。
- **无增长信号（全部 target = 0）→ fit nil**：对数后验无内部最大值
  （β0 → −∞ 永不收敛），100 次迭代后返回 nil；调用方走"显示当前粉丝数"兜底
  （与冷启动路径一致）。`testFlatDataPredictsNearZero` 断言相应改为 nil。

### 2.5 滚动预测（30 天累计增长分布）

```
对每条路径 i ∈ 1...500：
    θ_i ~ N(θ*, Σ)                     # Cholesky(Σ) + 标准正态
    levels ← 最近 8 点观测              # t−7...t
    for day in 1...30:
        x ← 特征(levels 末尾 7 点)      # 与训练期同 stats 标准化
        y ~ NegBinomial(e^{β·x}, φ)
        levels.append(last + y)
    total_i ← Σ y                      # 30 天累计增长
```

输出：均值 / 中位数 / 95% ETI（排序后 2.5%、97.5% 分位）/ P(增长>0) / 原始样本
（供 `probabilityAbove(threshold:)` 任意查询）。每条路径用同一个 θ_i 滚动
（同时涵盖参数不确定性与观测噪声）。

## 3. 文件布局

```
Follower/Services/Analysis/PredictionModel/
    Matrix.swift              # 小矩阵 + Accelerate dpotrf Cholesky + 三角求解
    Distributions.swift       # logGamma / digamma / normalCDF / 负二项密度 / Gamma-Poisson 采样
    FeatureEngine.swift       # GrowthPoint → FeatureRow（特征+截断目标）、标准化/反标准化
    NegativeBinomialGLM.swift # 对数后验、解析梯度、数值 Hessian
    LaplaceApproximation.swift# 牛顿法 MAP + 后验高斯
    RollingForecast.swift     # 500 样本 × 30 天滚动，ETI 分位数
FollowerTests/PredictionModelTests/
    TestHelpers.swift             # TestRNG（SplitMix64）+ 合成数据生成器
    MatrixTests / DistributionTests / FeatureEngineTests
    GLMGradientTests / LaplaceTests / RollingForecastTests
    SimulationCalibrationTests    # 20 组覆盖率 ≥ 0.70（理论 ~0.95）
```

## 4. 接口变更

`PredictionResult` 扩展（兼容现有字段，新增字段非破坏）：

```
predictedValue: Double      # 预测均值（UI 主值）
confidence: Double          # 0.95（固定，ETI 名义覆盖）
method: PredictionMethod    # .bayesianNB（原 .linear 替换）
lowerBound / upperBound     # 95% ETI
probabilityPositive         # P(增长 > 0)
growthSamples: [Double]     # 500 个累计增长样本（详情页分布图备用）
dailyLower/Q10/Q25/Median/Q75/Q90/Upper: [Double]  # 逐日累计增长分位（31 点，含起点 0）— 区间时序图
predictionDate: Date
```

## 4.1 UI（v0.15-alpha 详情页 + 主卡片）

- 组件 `PredictionTrendChart`（Swift Charts，零第三方依赖）：
  历史实线（LineMark）→ 未来中位数虚线（dash）→ **50/80/95% 三层 AreaMark 区间带**
  （95% = Q2.5-Q97.5 最浅 → 50% = Q25-Q75 最深）→ RuleMark "今天"线。
  compact 模式（卡片，隐藏轴）与全尺寸（详情页，主题化轴）两用。
- `PredictionDetailView`：主图 + 关键数字行（80% 区间 + P(增长>0)）；冷启动（result nil）
  显示空态提示（"need at least 30 days of data"），**不渲染任何图表**——
  单线折线回退已删除（v0.15.1：避免误导性旧图）。
- Dashboard 主卡片：粉丝预测 tile 在 `hasPredictionChart` 时跨双列（gridCellColumns(2)），
  内嵌紧凑图 + 一句话摘要；冷启动回退标准小 tile。

冷启动（< 30 特征行）→ 返回 nil，调用方（DashboardViewModel）保持现有兜底
（显示当前粉丝数）。`predictSMA` 保留不动。

### 4.2 Mock 数据覆盖保证（v0.15.1）

- Mock 数据源（`MockInstagramAPIClient`）覆盖 730 天日频粉丝序列 → 90 天窗口
  90 条快照，远超 38 点冷启动线，测试账号天然满足预测数据要求。
- **旧版（8/7 前）创建的测试账号只有静态 profile 快照（< 30 条）** →
  打开 app 时 `DashboardViewModel.loadAllData` 检测到 isTest 账号 + 90 天窗口
  快照不足 `LaplaceApproximation.minRows` → 自动补一次全量 mock 同步。
- 判定逻辑为纯函数 `needsAutoSyncForTestAccount(isTest:snapshotDays:isSyncing:)`，
  仅 isTest 账号触发（mock 同步零成本）；真实账号永不自动 sync（保护 API 配额）。
- 冷启动空态显示当前快照天数（`currently N days`），数据问题与模型问题一眼区分。

## 5. 设计决策记录

| 决策 | 选择 | 理由 |
|------|------|------|
| 推断算法 | Laplace 近似 | 确定性可测；6 维参数后验近似高斯足够好 |
| Hessian | 数值中心差分 | 避免 trigamma 实现错误；12 次梯度评估/步，毫秒级 |
| 目标截断 | y = max(0, Δ) | 负二项要求 y ≥ 0；取关指示 P3 再评估 |
| 可信 vs 置信 | 预测可信区间（95% ETI） | 业务语义是「未来增长落在区间的概率」 |
| 随机性注入 | 泛型 RandomNumberGenerator | 生产系统 RNG；测试注入 SplitMix64 确定性复现 |
| 特征标准化 | 训练期均值/标准差，滚动期复用 | 常数特征（预留位全 0）不缩放 |
| 冷启动 | <30 行返回 nil | 避免退化拟合；UI 走兜底 |
| 采样数 | 500 路径 × 30 天 | 毫秒级耗时，ETI 分位稳定 |
| 特征共线（v0.16） | 删除恒等式冗余特征 lag_growth_7d | 与 momentum_7d 严格线性相关 → 秩亏 → 拟合数值失败（真实数据复现） |
| 步长回退（v0.16） | 减半全败接受最佳有限候选 | 原 1e-6 阈值 10 次减半不可达，病态步长导致整体 nil |
| Hessian 符号（v0.17） | 牛顿步与协方差对 −H 加 jitter 后 solve | 对数后验全局凹 → H 负定；对 H 直接加正 jitter 使牛顿步反转（下降）→ fit 恒 nil（真实数据复现，消融 4 形态全失败→全成功） |

## 6. 测试策略

- **覆盖标准（v0.17）**：每个自实现函数（含 internal 纯辅助：dot /
  leastSquaresSlope / deduplicate / quantileIndex / choleskyWithJitter）至少 3 个
  单元测试（@Test），边界/手算/恒等式三面覆盖；确定性数学恒等式优先
  （logΓ 递推、ψ 递推、Φ 对称性、负二项概率归一化、Hessian 负定性、
  先验空行手算、Cholesky 重构、solve 往返）。
- 确定性函数精确断言：logΓ/digamma/CDF 已知值、特征手算、梯度 vs 数值差分（1e-4）。
- 采样统计量固定 seed 检查均值/方差（容差宽裕，防 flaky）。
- Laplace：合成数据 MAP 恢复真值（宽容差）、冷启动门槛、协方差正定、确定性。
- 校准：20 组参数各异的合成数据，95% CI 覆盖率 ≥ 0.70（理论 ~0.95，
  下限防采样 flaky）。
- 性能：单次 fit + forecast 应在毫秒级（Dashboard 后台任务，不阻塞主线程）。

## 7. 验收标准

- [x] 模型层 6 文件 + 测试 8 文件
- [x] PredictionResult 扩展 + predictLinear 切换 BayesianNB
- [x] 冷启动与兜底行为与现有一致
- [x] xcodebuild build-for-testing 通过
- [x] DashboardView 详情页展示区间与概率（PredictionTrendChart + 关键数字行）
- [x] Dashboard 主卡片紧凑图（跨双列 + 一句话摘要）
- [ ] P1.5：详情页逐日分布小图（点击交互）
- [ ] P2：预测记录表 + 轨迹回放图；特征贡献条（简化版）
