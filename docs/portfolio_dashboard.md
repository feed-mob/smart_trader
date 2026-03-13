# Portfolio Dashboard 设计说明

## 1. 页面目标

`Portfolio Dashboard` 是模拟盘的只读总览页，用来统一查看：

- 所有 trader 的组合净值
- 总盈亏与平均收益率
- 总组合收益曲线
- 单个 trader 的收益曲线
- 最近执行、持仓摘要、最近交易

这个页面的定位是：

- 结果总览页
- 收益监控页
- review 页面

它不是操作页，所以这里不承载：

- AI recommendation 生成
- recommendation 手动执行
- trader 编辑

这些操作继续放在：

- `traders`
- `traders/:id`
- `allocation_decisions`
- `allocation_tasks`

---

## 2. 路由与页面

路由：

- `/portfolio_dashboard`

代码位置：

- controller:
  - `app/controllers/portfolio_dashboards_controller.rb`
- view:
  - `app/views/portfolio_dashboards/show.html.erb`
- style:
  - `app/assets/stylesheets/traders.css`

首页入口：

- `home/index` 的 `Portfolio Dashboard` 模块卡片

---

## 3. 当前页面结构

页面目前分为 4 个主要区域：

### 3.1 顶部 Hero

展示页面名称和总览说明。

### 3.2 总指标区

展示：

- 总资产净值
- 总盈亏
- 平均收益率
- 活跃操盘手数量
- 当前持仓数
- 已完成执行次数

### 3.3 总组合趋势图区

展示：

- 总组合净值曲线
- 累计盈亏曲线

### 3.4 Trader 卡片区

每个 trader 卡片展示：

- 当前净值
- 当前累计盈亏
- 当前收益率
- 单独收益曲线
- 资产拆分
- 最近执行
- 当前持仓摘要
- 最近交易

---

## 4. 数据来源

### 4.1 Trader 基础数据

来自：

- `traders`

用于：

- 名称
- 风险等级
- 状态
- 初始资金

### 4.2 当前持仓数据

来自：

- `trader_positions`

用于：

- 当前持仓摘要
- 当前持仓数量
- 当前持仓市值

### 4.3 最近执行与最近交易

来自：

- `allocation_tasks`
- `trader_trades`

用于：

- 最近执行状态
- 最近执行时间
- 最近交易资产和时间

### 4.4 净值与收益曲线

来自：

- `portfolio_snapshots`

这是 `Portfolio Dashboard` 的核心历史数据来源。

---

## 5. 当前收益口径

### 5.1 卡片主数值

`Portfolio Dashboard` 卡片主数值当前优先读取：

- 最新一条 `portfolio_snapshot`

也就是说：

- 当前净值
- 当前盈亏
- 当前收益率

都优先来自最新快照，而不是直接用 `trader.current_capital`。

这样做的原因：

- 保证卡片和曲线的口径一致
- 避免“曲线一套、卡片一套”

### 5.2 总组合曲线

总组合曲线基于：

- 每个 trader 的 `portfolio_snapshots`
- 按 `snapshot_date` 分组
- 每天取 `captured_at` 最新一条
- 再按日期汇总为总组合净值

### 5.3 单个 trader 曲线

单个 trader 曲线基于：

- 该 trader 的 `portfolio_snapshots`
- 按 `snapshot_date` 分组
- 每天取最新一条

---

## 6. portfolio_snapshots 的来源

当前 `portfolio_snapshots.source` 支持两类：

### 6.1 `execution`

来源：

- `AllocationExecutionService`

含义：

- recommendation 执行完成后的净值快照

用途：

- 记录调仓执行结果

### 6.2 `mark_to_market`

来源：

- `MarkToMarketPortfolioSnapshotsJob`

含义：

- 不执行调仓，只按最新价格做盯市估值

用途：

- 记录日常收益变化
- 支撑更连续的收益曲线

---

## 7. 当前已知设计取舍

### 7.1 历史 `mark_to_market` 回填是近似值

当前支持用脚本补指定日期的 `mark_to_market` 快照，但这属于近似回填。

原因：

- 系统没有独立的历史持仓快照表
- 只能用当前持仓数量 + 指定日期价格做近似估值

所以：

- 用于 review 和大致收益观察可以接受
- 不能把历史回填结果当作绝对精确的历史账本

### 7.2 当前页与历史页的边界

`Portfolio Dashboard` 更偏：

- 组合结果展示
- 收益趋势观察

它不是：

- 精细交易回放页
- 精确审计页

精细执行和成交回放应该去看：

- `allocation_tasks`
- `trader_trades`

---

## 8. 当前相关任务

### 自动任务顺序

当前 scheduler 顺序：

1. `GenerateSignalsJob`
2. `GenerateDailyAllocationDecisionsJob`
3. `ExecuteDailyAllocationDecisionsJob`
4. `MarkToMarketPortfolioSnapshotsJob`

当前时间：

- `GenerateSignalsJob`：UTC `03:00 / 15:00`
- `GenerateDailyAllocationDecisionsJob`：UTC `03:10 / 15:10`
- `ExecuteDailyAllocationDecisionsJob`：UTC `03:20 / 15:20`
- `MarkToMarketPortfolioSnapshotsJob`：UTC `03:30 / 15:30`

---

## 9. 手动维护命令

### 回填历史 execution 快照

```bash
bin/rails runner 'pp PortfolioSnapshotBackfillService.new.call'
```

### 回填指定日期的 mark-to-market 快照

```bash
bin/rails runner script/backfill_mark_to_market_snapshots.rb 2026-03-16
```

强制重跑：

```bash
bin/rails runner script/backfill_mark_to_market_snapshots.rb 2026-03-16 --force
```

### 手动执行日常盯市快照

```bash
bin/rails runner 'pp MarkToMarketPortfolioSnapshotService.new.call'
```

---

## 10. 后续建议

后面如果继续优化 `Portfolio Dashboard`，优先级建议如下：

1. 统一卡片与详情页的收益口径
2. 增加 tooltip / 日期 hover 信息
3. 增加按 trader 筛选曲线
4. 增加 snapshot 来源过滤（`execution` / `mark_to_market`）
5. 如果以后需要更精确历史收益，再考虑增加“历史持仓快照层”
