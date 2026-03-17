# 模拟盘系统说明

## 1. 目标

当前模拟盘系统的核心目标是：

- 先由 LLM 生成正式配置建议
- 再由系统决定是否执行
- recommendation 和 execution 分开建模
- 执行结果可以回看、审计和总览展示

上一版之所以推翻，核心原因有三点：

1. 把 LLM 建议和执行任务混在一起，职责不清。
2. 执行层又按信号自己推导买卖，可能和 LLM 建议不一致。
3. `portfolio_positions`、`portfolio_transactions` 这类命名不符合当前以 `trader` 为主体的模型。

---

## 2. 当前状态

当前已完成：

- Phase 0：清理旧实现
- Phase 1：表和 Model
- Phase 2：recommendation 落库
- Phase 2.5：recommendation 只读页面
- Phase 3A：手动执行 recommendation
- Phase 3B：交易流水 `trader_trades`
- Phase 4.5：独立 `Portfolio Dashboard`
- Phase 5A：自动生成 recommendation
- Phase 5B：自动执行 recommendation
- Phase 5C：接入 Sidekiq scheduler

当前未完成：

- Phase 5D：更细的防重、失败记录与重跑策略

---

## 3. 当前系统链路

当前主链路已经形成闭环：

1. `AiAllocationService`
   生成 recommendation
2. `allocation_decisions`
   保存正式建议
3. `AllocationExecutionService`
   执行 recommendation
4. `allocation_tasks`
   保存执行结果
5. `portfolio_snapshots`
   保存净值历史快照
6. `trader_positions`
   保存当前持仓
7. `trader_trades`
   保存交易流水
8. `Portfolio Dashboard`
   展示总组合与单 trader 收益结果

自动任务链路如下：

1. `GenerateSignalsJob`
2. `GenerateDailyAllocationDecisionsJob`
3. `ExecuteDailyAllocationDecisionsJob`
4. `MarkToMarketPortfolioSnapshotsJob`

当前 `sidekiq.yml` 调度顺序：

- `GenerateSignalsJob`：UTC `03:00 / 15:00`
- `GenerateDailyAllocationDecisionsJob`：UTC `03:10 / 15:10`
- `ExecuteDailyAllocationDecisionsJob`：UTC `03:20 / 15:20`
- `MarkToMarketPortfolioSnapshotsJob`：UTC `03:30 / 15:30`

---

## 4. 分阶段记录

### Phase 0：清理旧实现

已移除：

- 规则型每日调仓 service
- 旧的自动调仓 job / scheduler
- `allocation_runs`
- `portfolio_positions`
- `portfolio_transactions`

### Phase 1：表和 Model

已新增：

- `allocation_decisions`
- `allocation_tasks`
- `trader_positions`

本阶段只做了：

- migration
- ActiveRecord model
- associations
- validations
- 基础 scopes

### Phase 2：Recommendation Service

已完成：

- `AiAllocationService` 支持 recommendation 落库
- recommendation 写入 `allocation_decisions`
- 记录 `source`、`llm_model_name`、`validation_status`
- 预览页复用同一份已落库数据
- recommendation 生成时会显式读取当前持仓上下文，不再默认按空仓重建组合
- prompt 已增加“优先评估现有持仓、减少无意义换仓、移除老仓位必须说明理由”的约束
- 已新增 `GetCurrentPortfolio` tool，LLM 可主动读取当前现金、持仓、仓位占比和最近执行摘要

### Phase 2.5：Recommendation Readonly UI

已完成：

- `allocation_decisions#index`
- `allocation_decisions#show`

定位：

- recommendation 审计页
- 开发验证页
- 执行前输入检查页

### Phase 3A：Manual Execution

已完成：

- 新增 `AllocationExecutionService`
- 手动执行单条 `allocation_decision`
- 写入 `allocation_tasks`
- 更新 `trader_positions`
- 回写 `trader.current_capital`

当前执行原则：

- 执行层不重新做投资决策
- 以 `allocation_percent` 作为目标组合的唯一依据
- recommendation 中没有的旧仓位视为目标仓位 0

当前执行前校验：

- strategy 必须存在
- `allocations + cash_reserve = 100`
- 持仓数不超过 `max_positions`
- 单仓不超过 `max_position_size`
- recommendation 中资产必须存在且有最新价格

### Phase 3B：Trade Ledger

已完成：

- 新增 `trader_trades`
- recommendation 执行时写入交易流水
- `allocation_tasks#show` 展示本次成交
- `trader#show` 展示最近交易

当前规则：

- 新增/加仓写 `buy`
- 减仓/清仓写 `sell`
- recommendation 不包含的旧仓位会生成清仓 `sell`
- `hold` 不写流水

### Phase 3C：Portfolio Snapshots

已完成：

- 新增 `portfolio_snapshots`
- 每次 recommendation 执行完成后自动写一条净值快照
- 支持从历史 `allocation_tasks` 回填 `portfolio_snapshots`
- 新增 `MarkToMarketPortfolioSnapshotsJob`，用于日常按最新价格写盯市快照
- 新增 `script/backfill_mark_to_market_snapshots.rb`，可手动补指定日期的盯市快照
- 快照记录现金、持仓市值、总净值、盈亏和收益率
- `Portfolio Dashboard` 曲线已改读 `portfolio_snapshots`
- 回填历史 `mark_to_market` 快照时，价格和现金基准按 `run_at` 回看历史数据，不直接使用当天最新值

### Phase 4：基础执行结果页面

已完成：

- `allocation_tasks` 列表页
- `allocation_tasks` 详情页
- `allocation_decision` 详情页展示最近执行结果
- `trader` 详情页展示当前持仓和最近执行摘要

### Phase 4.5：Portfolio Dashboard

已完成：

- 新增独立路由 `/portfolio_dashboard`
- 首页 `Portfolio Dashboard` 模块卡片已接入真实页面
- 页面为只读总览，不承载 recommendation / execution 手动操作
- 展示总组合净值、总盈亏、平均收益率
- 展示总组合净值曲线和累计盈亏曲线
- 每个 trader 展示单独收益曲线、最近执行、持仓摘要、最近交易
- 详细页面设计与收益口径见 `docs/portfolio_dashboard.md`

当前口径：

- Dashboard 盈亏按最新价格盯市计算
- 公式为：`最近一次执行后的现金 + 当前持仓按最新快照估值`
- 趋势图基于 `portfolio_snapshots.portfolio_value`
- `portfolio_snapshots.source` 当前支持：
  - `execution`
  - `mark_to_market`
- Dashboard 卡片主数值优先读取最新 `portfolio_snapshot`，保证与收益曲线口径一致

### Phase 5A：Daily Recommendation Generation

已完成：

- 新增 `DailyAllocationDecisionGenerationService`
- 新增 `GenerateDailyAllocationDecisionsJob`
- 遍历活跃 trader 自动生成 `allocation_decisions`

当前默认规则：

- 同一 trader 同一天已存在 LLM recommendation 时跳过
- 支持 `force: true` 强制重跑

### Phase 5B：Daily Recommendation Execution

已完成：

- 新增 `DailyAllocationExecutionService`
- 新增 `ExecuteDailyAllocationDecisionsJob`
- 遍历活跃 trader，执行当天最新有效 recommendation

当前默认规则：

- 只消费 `decision_date = run_on` 的 recommendation
- 如果同一 trader 在同一天存在多条有效 recommendation，默认取 `created_at` 最新的一条执行
- 若同一条 decision 已有 `running/completed` task，则跳过
- 支持 `force: true` 强制重跑

### Phase 5C：Scheduler

已完成：

- 已在 `config/sidekiq.yml` 接入 recommendation generation / execution 调度
- recommendation、execution、mark-to-market snapshot 保持分离，通过时间顺序串联

### Phase 5D：待做

下一步需要补的内容：

- 更细的防重规则
- 失败记录与重跑策略
- 是否支持某些 trader “只生成不执行”

---

## 5. 当前数据模型

### `allocation_decisions`

用途：保存 LLM 正式生成的资产配置建议。

关键字段：

- `trader_id`
- `trading_strategy_id`
- `decision_date`
- `status`
- `source`
- `llm_model_name`
- `validation_status`
- `selected_strategy`
- `market_analysis`
- `summary`
- `recommendation_payload`
- `error_message`
- `generated_at`

语义：

> AI 想怎么配。

### `allocation_tasks`

用途：保存系统是否执行了某条 recommendation，以及执行结果。

关键字段：

- `trader_id`
- `allocation_decision_id`
- `run_on`
- `status`
- `starting_cash`
- `ending_cash`
- `portfolio_value`
- `summary`
- `error_message`
- `execution_payload`
- `started_at`
- `completed_at`

语义：

> 系统哪天有没有执行、执行结果怎么样。

当前约束：

- 不对 `(trader_id, run_on)` 做唯一约束
- 同一个 trader 同一天允许执行多次
- 是否重复执行由 service 层控制

### `portfolio_snapshots`

用途：保存某一时点的组合净值快照，是净值历史层数据。

关键字段：

- `trader_id`
- `allocation_task_id`
- `snapshot_date`
- `captured_at`
- `cash_value`
- `invested_value`
- `portfolio_value`
- `profit_loss`
- `profit_loss_percent`
- `source`
- `metadata`

语义：

> 这个 trader 在某个时间点的组合净值是多少。

### `trader_positions`

用途：保存 trader 当前持仓。

关键字段：

- `trader_id`
- `asset_id`
- `quantity`
- `average_cost`
- `current_price`
- `market_value`
- `unrealized_pnl`
- `unrealized_pnl_percent`
- `active`
- `opened_at`
- `last_rebalanced_at`

语义：

> 这个操盘手现在手里持有什么。

采用 `trader_positions` 而不是 `portfolio_positions` 的原因：

- 当前主体是 `trader`
- 项目里没有 `portfolios` 主表
- `portfolio_*` 容易造成错误联想

### `trader_trades`

用途：保存模拟盘交易流水，是执行明细层数据。

关键字段：

- `trader_id`
- `allocation_task_id`
- `allocation_decision_id`
- `asset_id`
- `action`
- `quantity`
- `price`
- `amount`
- `reason`
- `executed_at`

语义：

> 这次执行任务到底实际成交了哪些单子。

和 `trader_positions` 的区别：

- `trader_positions` 是当前结果
- `trader_trades` 是历史流水

---

## 6. 已确认但尚未实现的建议

### 表级建议

- `trader_positions` 后续可增加 `cost_basis`
- `allocation_decisions` 后续可增加 `expires_at`
- `allocation_tasks` 后续可增加 `attempt_no` 或 `run_at`
- `portfolio_snapshots` 后续可支持 `mark_to_market` 来源的日终估值快照

### 字段级建议

- `allocation_decisions.source`
  - 建议来源，如 `llm`、`manual`
- `allocation_decisions.llm_model_name`
  - 生成 recommendation 的模型名
- `allocation_decisions.validation_status`
  - recommendation 是否可执行

### 约束建议

- `allocation_tasks` 继续保持无 `(trader_id, run_on)` 唯一约束
- 同一天允许多次执行
- 是否重复执行由 service 控制，不交给数据库唯一索引

---

## 7. 下一步

下一步进入 Phase 5D：

1. 补更细的防重规则
2. 明确失败记录与重跑策略
3. 评估是否增加“仅生成不执行”的 trader 级开关
