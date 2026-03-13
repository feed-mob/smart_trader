# SmartTrader 数据库设计文档

## 1. 数据库概览

SmartTrader 数据库采用 PostgreSQL 14+，包含 10 个核心表，遵循以下设计原则：

- **领域驱动设计 (DDD)**: 表结构反映业务领域概念（如 Trader、TradingStrategy、TradingSignal）
- **规范化设计**: 避免数据冗余，使用外键关联建立表间关系
- **可扩展性**: 支持动态因子定义和策略配置
- **性能优化**: 为频繁查询字段建立适当索引
- **分析友好**: 保存完整的历史数据快照和因子值序列

---

## 2. 详细表结构

### 2.1 users (用户表)

| 字段名               | 类型          | 约束           | 说明                     |
|---------------------|---------------|----------------|--------------------------|
| id                  | bigint        | PRIMARY KEY    | 主键                     |
| google_id           | string        | UNIQUE, INDEX  | Google OAuth 用户ID     |
| email               | string        | NOT NULL, UNIQUE, INDEX | 邮箱地址         |
| email_verified      | boolean       | DEFAULT false  | 邮箱验证状态             |
| name                | string        | NOT NULL       | 用户姓名                 |
| avatar_url          | string        |                | 头像URL                  |
| created_at          | datetime      | NOT NULL       | 创建时间                 |
| updated_at          | datetime      | NOT NULL       | 更新时间                 |

**索引**:
- `index_users_on_email_and_google_id (email, google_id)` (复合唯一索引)
- `index_users_on_email` (唯一索引)
- `index_users_on_google_id` (唯一索引)

**关联关系**:
- 无直接外键关联（当前设计）

---

### 2.2 traders (操盘手表)

| 字段名               | 类型          | 约束           | 说明                     |
|---------------------|---------------|----------------|--------------------------|
| id                  | bigint        | PRIMARY KEY    | 主键                     |
| user_id             | bigint        | NOT NULL, FOREIGN KEY | 用户ID          |
| name                | string        | NOT NULL       | 操盘手名称               |
| description         | text          |                | 操盘手描述（投资风格）   |
| initial_capital     | decimal(15,2) | NOT NULL, DEFAULT 100000.0 | 初始资金       |
| current_capital     | decimal(15,2) |                | 当前资金                 |
| risk_level          | integer       | DEFAULT 0      | 风险等级 (0:保守, 1:平衡, 2:激进) |
| status              | integer       | DEFAULT 0      | 状态 (0:活跃, 1:停用)   |
| created_at          | datetime      | NOT NULL       | 创建时间                 |
| updated_at          | datetime      | NOT NULL       | 更新时间                 |

**索引**:
- `index_traders_on_user_id`
- `index_traders_on_status`

**关联关系**:
- `belongs_to :user`
- `has_many :trading_strategies`

**枚举值**:
- risk_level: { conservative: 0, balanced: 1, aggressive: 2 }
- status: { active: 0, inactive: 1 }

---

### 2.3 trading_strategies (交易策略表)

| 字段名                  | 类型          | 约束           | 说明                     |
|------------------------|---------------|----------------|--------------------------|
| id                     | bigint        | PRIMARY KEY    | 主键                     |
| trader_id              | bigint        | NOT NULL, FOREIGN KEY | 操盘手ID        |
| name                   | string        | NOT NULL       | 策略名称                 |
| market_condition       | integer       | NOT NULL, DEFAULT 0 | 市场条件 (0:正常, 1:高波动, 2:崩盘, 3:泡沫) |
| risk_level             | integer       | DEFAULT 1      | 风险等级 (同traders表)   |
| max_positions          | integer       | DEFAULT 3      | 最大持仓数 (2-5)         |
| buy_signal_threshold   | decimal(3,2)  | DEFAULT 0.5, CHECK (0.3-0.7) | 买入信号阈值 |
| max_position_size      | decimal(3,2)  | DEFAULT 0.5, CHECK (0.3-0.7) | 单仓位最大占比 |
| min_cash_reserve       | decimal(3,2)  | DEFAULT 0.2, CHECK (0.05-0.4) | 最小现金储备 |
| generated_by           | integer       | DEFAULT 0      | 策略生成方式 (0:LLM, 1:手动, 2:默认模板, 3:矩阵) |
| description            | text          |                | 策略描述                 |
| created_at             | datetime      | NOT NULL       | 创建时间                 |
| updated_at             | datetime      | NOT NULL       | 更新时间                 |

**索引**:
- `index_trading_strategies_on_trader_id_and_market_condition (trader_id, market_condition)` (复合唯一索引)

**关联关系**:
- `belongs_to :trader`
- `has_many :strategy_factor_weights`

**枚举值**:
- market_condition: { normal: 0, volatile: 1, crash: 2, bubble: 3 }
- generated_by: { llm: 0, manual: 1, default_template: 2, matrix: 3 }

---

### 2.4 assets (资产表)

| 字段名               | 类型          | 约束           | 说明                     |
|---------------------|---------------|----------------|--------------------------|
| id                  | bigint        | PRIMARY KEY    | 主键                     |
| symbol              | string        | NOT NULL, INDEX | 资产代码 (如 BTC, AAPL) |
| name                | string        | NOT NULL       | 资产名称                 |
| asset_type          | string        | NOT NULL       | 资产类型 (stock/crypto/etf等) |
| exchange            | string        | NOT NULL, DEFAULT 'UNKNOWN' | 交易所/市场 (BINANCE, NASDAQ, SSE等) |
| quote_currency      | string        | NOT NULL, DEFAULT 'USD' | 计价货币 (USDT, USD, CNY等) |
| coingecko_id        | string        | INDEX          | CoinGecko 币种 ID (仅加密货币) |
| yahoo_symbol        | string        | INDEX          | Yahoo Finance Symbol (如 BTC-USD, AAPL) |
| current_price       | decimal(15,2) |                | 当前价格                 |
| last_updated        | datetime      |                | 价格最后更新时间         |
| active              | boolean       | DEFAULT true, INDEX | 是否活跃交易         |
| created_at          | datetime      | NOT NULL       | 创建时间                 |
| updated_at          | datetime      | NOT NULL       | 更新时间                 |

**索引**:
- `index_assets_on_symbol_exchange_quote (symbol, exchange, quote_currency)` (复合唯一索引)
- `index_assets_on_coingecko_id` (唯一索引，仅加密货币)
- `index_assets_on_yahoo_symbol` (唯一索引，仅股票)
- `index_assets_on_asset_type`
- `index_assets_on_active`

**关联关系**:
- `has_many :asset_snapshots, dependent: :destroy`
- `has_many :factor_values, dependent: :destroy`
- `has_many :trading_signals, dependent: :destroy`

---

### 2.5 asset_snapshots (资产快照表)

| 字段名               | 类型          | 约束           | 说明                     |
|---------------------|---------------|----------------|--------------------------|
| id                  | bigint        | PRIMARY KEY    | 主键                     |
| asset_id            | bigint        | NOT NULL, FOREIGN KEY | 资产ID          |
| snapshot_date       | date          | NOT NULL, INDEX | 快照日期（用于查询和唯一性约束） |
| captured_at         | datetime      | NOT NULL, INDEX | 实际采集时间（精确时间戳） |
| price               | decimal(15,2) | NOT NULL       | 资产价格                 |
| change_percent      | decimal(8,4)  |                | 价格涨跌幅 (%)           |
| volume              | decimal(20,2) |                | 成交量                   |
| created_at          | datetime      | NOT NULL       | 创建时间                 |
| updated_at          | datetime      | NOT NULL       | 更新时间                 |

**索引**:
- `index_asset_snapshots_on_asset_id_and_snapshot_date (asset_id, snapshot_date)` (复合唯一索引)
- `index_asset_snapshots_on_snapshot_date`
- `index_asset_snapshots_on_captured_at`

**关联关系**:
- `belongs_to :asset`

**关联关系**:
- `belongs_to :asset`

---

### 2.6 candles (K线数据表)

| 字段名               | 类型          | 约束           | 说明                     |
|---------------------|---------------|----------------|--------------------------|
| id                  | bigint        | PRIMARY KEY    | 主键                     |
| asset_id            | bigint        | NOT NULL, FOREIGN KEY | 资产ID          |
| interval            | string        | NOT NULL, DEFAULT '4h' | 时间周期 (1m/5m/15m/1h/4h/1d/1w) |
| candle_time         | datetime      | NOT NULL, INDEX | K线开始时间             |
| open_price          | decimal(15,2) | NOT NULL       | 开盘价                   |
| high_price          | decimal(15,2) | NOT NULL       | 最高价                   |
| low_price           | decimal(15,2) | NOT NULL       | 最低价                   |
| close_price         | decimal(15,2) | NOT NULL       | 收盘价                   |
| volume              | decimal(20,2) |                | 成交量                   |
| quote_volume        | decimal(20,2) |                | 成交额                   |
| created_at          | datetime      | NOT NULL       | 创建时间                 |
| updated_at          | datetime      | NOT NULL       | 更新时间                 |

**索引**:
- `index_candles_on_asset_id_and_interval_and_candle_time (asset_id, interval, candle_time)` (复合唯一索引)
- `index_candles_on_candle_time`
- `index_candles_on_asset_id_and_interval`

**关联关系**:
- `belongs_to :asset`

**业务说明**:
- 主要用于4小时K线监控和技术分析
- 支持多种时间周期，但默认使用4小时（4h）
- 用于计算技术指标：MACD、RSI、布林带等
- 存储策略：4小时线保留1-2年，日线长期保留

---

### 2.7 trading_signals (交易信号表)

| 字段名               | 类型          | 约束           | 说明                     |
|---------------------|---------------|----------------|--------------------------|
| id                  | bigint        | PRIMARY KEY    | 主键                     |
| asset_id            | bigint        | NOT NULL, FOREIGN KEY | 资产ID          |
| signal_type         | string        | NOT NULL, INDEX | 信号类型 (buy/sell/hold) |
| generated_at        | datetime      | NOT NULL       | 信号生成时间             |
| confidence          | decimal(3,2)  |                | 信号置信度 (0-1)         |
| reasoning           | text          |                | LLM 推理过程             |
| risk_warning        | text          |                | 风险提示                 |
| key_factors         | jsonb         | DEFAULT []     | 关键因子列表             |
| factor_snapshot     | jsonb         | DEFAULT {}     | 因子值快照               |
| created_at          | datetime      | NOT NULL       | 创建时间                 |
| updated_at          | datetime      | NOT NULL       | 更新时间                 |

**索引**:
- `index_trading_signals_on_asset_id_and_generated_at (asset_id, generated_at)` (复合索引)
- `index_trading_signals_on_asset_id`
- `index_trading_signals_on_signal_type`

**关联关系**:
- `belongs_to :asset`

**枚举值**:
- signal_type: buy, sell, hold

---

### 2.8 factor_definitions (因子定义表)

| 字段名               | 类型          | 约束           | 说明                     |
|---------------------|---------------|----------------|--------------------------|
| id                  | bigint        | PRIMARY KEY    | 主键                     |
| code                | string        | NOT NULL, UNIQUE, INDEX | 因子代码 (如 'rsi') |
| name                | string        | NOT NULL       | 因子名称                 |
| category            | string        | NOT NULL, INDEX | 因子类别 (technical/fundamental/sentiment等) |
| calculation_method  | string        | NOT NULL       | 计算方法                 |
| formula             | text          |                | 计算公式（可选）         |
| description         | text          |                | 因子描述                 |
| weight              | decimal(5,4)  | DEFAULT 0.1, CHECK (0-1) | 因子权重         |
| active              | boolean       | DEFAULT true, INDEX | 是否启用             |
| parameters          | jsonb         | DEFAULT {}     | 参数配置 (JSON格式)      |
| update_frequency    | integer       | DEFAULT 60     | 更新频率 (秒)            |
| sort_order          | integer       | DEFAULT 0      | 排序顺序                 |
| created_at          | datetime      | NOT NULL       | 创建时间                 |
| updated_at          | datetime      | NOT NULL       | 更新时间                 |

**索引**:
- `index_factor_definitions_on_code` (唯一索引)
- `index_factor_definitions_on_category`
- `index_factor_definitions_on_active`

**关联关系**:
- `has_many :factor_values, dependent: :destroy`
- `has_many :strategy_factor_weights, dependent: :destroy`

**因子类别**:
- technical (技术因子)
- fundamental (基本面因子)
- sentiment (情绪因子)
- momentum (动量因子)
- risk (风险因子)
- volume (成交量因子)

---

### 2.9 factor_values (因子值表)

| 字段名               | 类型          | 约束           | 说明                     |
|---------------------|---------------|----------------|--------------------------|
| id                  | bigint        | PRIMARY KEY    | 主键                     |
| asset_id            | bigint        | NOT NULL, FOREIGN KEY | 资产ID          |
| factor_definition_id| bigint        | NOT NULL, FOREIGN KEY | 因子定义ID      |
| calculated_at       | datetime      | NOT NULL, INDEX | 计算时间                 |
| raw_value           | decimal(15,6) |                | 原始值                   |
| normalized_value    | decimal(10,6) |                | 标准化值 (-1 到 1)       |
| percentile          | decimal(5,2)  |                | 分位数 (0-100)           |
| created_at          | datetime      | NOT NULL       | 创建时间                 |
| updated_at          | datetime      | NOT NULL       | 更新时间                 |

**索引**:
- `idx_factor_values_unique (asset_id, factor_definition_id, calculated_at)` (复合唯一索引)
- `index_factor_values_on_asset_id`
- `index_factor_values_on_factor_definition_id`
- `index_factor_values_on_calculated_at`

**关联关系**:
- `belongs_to :asset`
- `belongs_to :factor_definition`

---

### 2.10 strategy_factor_weights (策略因子权重表)

| 字段名               | 类型          | 约束           | 说明                     |
|---------------------|---------------|----------------|--------------------------|
| id                  | bigint        | PRIMARY KEY    | 主键                     |
| trading_strategy_id | bigint        | NOT NULL, FOREIGN KEY | 策略ID          |
| factor_definition_id| bigint        | NOT NULL, FOREIGN KEY | 因子定义ID      |
| weight              | decimal(5,4)  | DEFAULT 0.1, CHECK (0-1) | 因子权重         |
| created_at          | datetime      | NOT NULL       | 创建时间                 |
| updated_at          | datetime      | NOT NULL       | 更新时间                 |

**索引**:
- `index_strategy_factor_weights_on_trading_strategy_id`
- `index_strategy_factor_weights_on_factor_definition_id`

**关联关系**:
- `belongs_to :trading_strategy`
- `belongs_to :factor_definition`

---

## 3. 表关联关系图

```mermaid
erDiagram
    users ||--o{ traders : "拥有"
    traders ||--|{ trading_strategies : "配置"
    traders ||--o{ allocation_decisions : "生成建议"
    traders ||--o{ allocation_tasks : "执行任务"
    traders ||--o{ trader_positions : "持仓"
    trading_strategies ||--|{ strategy_factor_weights : "包含"
    trading_strategies ||--o{ allocation_decisions : "被采用"

    assets ||--|{ asset_snapshots : "有历史快照"
    assets ||--|{ factor_values : "有因子值"
    assets ||--|{ trading_signals : "产生信号"
    assets ||--o{ trader_positions : "构成持仓"

    factor_definitions ||--|{ factor_values : "定义"
    factor_definitions ||--|{ strategy_factor_weights : "被引用"

    allocation_decisions ||--o{ allocation_tasks : "被执行"
    trading_strategies }|..|{ assets : "适用"
    trading_signals }|..|{ traders : "被使用"
```

---

## 4. 设计建议

### 4.1 当前设计的优点

1. **清晰的领域模型映射**: 表结构直接反映业务概念
2. **强大的策略配置**: 支持3×4矩阵的预设策略和动态生成策略
3. **灵活的因子系统**: 支持12种因子类别和自定义计算方法
4. **完整的历史记录**: 保存资产价格快照和因子值序列
5. **性能优化**: 为高频查询建立了适当索引

### 4.2 模拟盘 Phase 1 新增表

#### 4.2.1 allocation_decisions (资产配置建议表)

用于保存 LLM 生成的正式配置建议，是“决策层”数据，不是执行结果。

| 字段名                 | 类型          | 约束           | 说明 |
|----------------------|---------------|----------------|------|
| id                   | bigint        | PRIMARY KEY    | 主键 |
| trader_id            | bigint        | NOT NULL, FOREIGN KEY | 操盘手 ID |
| trading_strategy_id  | bigint        | FOREIGN KEY    | 被采用的策略 ID，可为空 |
| decision_date        | date          | NOT NULL, INDEX | 建议日期 |
| status               | integer       | NOT NULL, DEFAULT 0 | 建议生成状态 |
| source               | string        | NOT NULL, DEFAULT 'llm' | 建议来源 |
| llm_model_name       | string        |                | 生成建议的模型名 |
| validation_status    | integer       | NOT NULL, DEFAULT 0 | 执行前校验状态 |
| selected_strategy    | string        |                | LLM 选择的策略标识 |
| market_analysis      | text          |                | 市场分析 |
| summary              | text          |                | 配置摘要 |
| error_message        | text          |                | 生成或校验失败原因 |
| recommendation_payload | jsonb       | NOT NULL, DEFAULT {} | recommendation 原始 JSON |
| generated_at         | datetime      |                | 建议生成时间 |
| created_at           | datetime      | NOT NULL       | 创建时间 |
| updated_at           | datetime      | NOT NULL       | 更新时间 |

**索引**:
- `index_allocation_decisions_on_trader_id_and_decision_date`
- `index_allocation_decisions_on_status`

**关联关系**:
- `belongs_to :trader`
- `belongs_to :trading_strategy, optional: true`
- `has_many :allocation_tasks`

**枚举值**:
- status: { pending: 0, generated: 1, invalid_payload: 2, failed: 3 }
- validation_status: { pending_validation: 0, valid_payload: 1, invalid_payload: 2 }

#### 4.2.2 allocation_tasks (资产配置执行任务表)

用于保存某一天某次是否执行了某份配置建议，是“执行层”数据。

| 字段名               | 类型          | 约束           | 说明 |
|---------------------|---------------|----------------|------|
| id                  | bigint        | PRIMARY KEY    | 主键 |
| trader_id           | bigint        | NOT NULL, FOREIGN KEY | 操盘手 ID |
| allocation_decision_id | bigint     | FOREIGN KEY    | 对应的配置建议，可为空 |
| run_on              | date          | NOT NULL, INDEX | 执行日期 |
| status              | integer       | NOT NULL, DEFAULT 0 | 执行状态 |
| starting_cash       | decimal(15,2) | NOT NULL, DEFAULT 0 | 执行前现金 |
| ending_cash         | decimal(15,2) | NOT NULL, DEFAULT 0 | 执行后现金 |
| portfolio_value     | decimal(15,2) | NOT NULL, DEFAULT 0 | 执行后组合净值 |
| summary             | text          |                | 执行摘要 |
| error_message       | text          |                | 执行失败原因 |
| execution_payload   | jsonb         | NOT NULL, DEFAULT {} | 执行附加信息 |
| started_at          | datetime      |                | 开始执行时间 |
| completed_at        | datetime      |                | 完成执行时间 |
| created_at          | datetime      | NOT NULL       | 创建时间 |
| updated_at          | datetime      | NOT NULL       | 更新时间 |

**索引**:
- `index_allocation_tasks_on_trader_id_and_run_on`
- `index_allocation_tasks_on_status`

**关联关系**:
- `belongs_to :trader`
- `belongs_to :allocation_decision, optional: true`

**业务说明**:
- 不对 `(trader_id, run_on)` 做唯一约束
- 同一个操盘手同一天允许执行多次
- 防止重复执行应在 service 层控制，不在本阶段用数据库唯一索引限制

**枚举值**:
- status: { pending: 0, running: 1, completed: 2, failed: 3, skipped: 4 }

#### 4.2.3 trader_positions (操盘手持仓表)

用于保存操盘手当前持仓，是“结果层”数据。

| 字段名                 | 类型          | 约束           | 说明 |
|----------------------|---------------|----------------|------|
| id                   | bigint        | PRIMARY KEY    | 主键 |
| trader_id            | bigint        | NOT NULL, FOREIGN KEY | 操盘手 ID |
| asset_id             | bigint        | NOT NULL, FOREIGN KEY | 资产 ID |
| quantity             | decimal(20,8) | NOT NULL, DEFAULT 0 | 持仓数量 |
| average_cost         | decimal(15,2) | NOT NULL, DEFAULT 0 | 持仓均价 |
| current_price        | decimal(15,2) | NOT NULL, DEFAULT 0 | 当前价格 |
| market_value         | decimal(15,2) | NOT NULL, DEFAULT 0 | 当前市值 |
| unrealized_pnl       | decimal(15,2) | NOT NULL, DEFAULT 0 | 浮盈亏 |
| unrealized_pnl_percent | decimal(8,2)| NOT NULL, DEFAULT 0 | 浮盈亏比例 |
| active               | boolean       | NOT NULL, DEFAULT true | 是否活跃 |
| opened_at            | datetime      |                | 开仓时间 |
| last_rebalanced_at   | datetime      |                | 最近调仓时间 |
| created_at           | datetime      | NOT NULL       | 创建时间 |
| updated_at           | datetime      | NOT NULL       | 更新时间 |

**索引**:
- `index_trader_positions_on_trader_id_and_asset_id` (复合唯一索引)
- `index_trader_positions_on_trader_id_and_active`

**关联关系**:
- `belongs_to :trader`
- `belongs_to :asset`

**业务说明**:
- 采用 `trader_positions` 而不是 `portfolio_positions`
- 当前业务主体是 `trader`，系统中没有独立的 `portfolios` 主表
- 当前阶段只保存当前持仓，不包含交易流水

### 4.3 后续扩展建议

1. **trader_positions 表**: 后续可添加 `cost_basis` 字段支持更精确的分批建仓与减仓成本计算
2. **allocation_decisions 表**: 后续可添加 `expires_at` 字段管理建议有效期
3. **allocation_tasks 表**: 后续可添加 `attempt_no` 或 `run_at` 字段支持更细粒度的多次执行追踪
4. **执行层表**: Phase 3 已新增 `trader_trades` 表保存模拟交易流水，结构如下：

```sql
CREATE TABLE trader_trades (
    id bigint PRIMARY KEY,
    trader_id bigint NOT NULL REFERENCES traders,
    allocation_task_id bigint REFERENCES allocation_tasks,
    allocation_decision_id bigint REFERENCES allocation_decisions,
    asset_id bigint NOT NULL REFERENCES assets,
    action varchar NOT NULL, -- buy / sell
    quantity decimal(20,8) NOT NULL,
    price decimal(15,2) NOT NULL,
    amount decimal(15,2) NOT NULL,
    reason text,
    executed_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL
);
```

用途说明：
- 保存每一笔模拟成交流水
- 连接 recommendation、execution task 和当前持仓结果
- 用于后续交易历史、调仓审计、盈亏回放

补充说明：
- Phase 2.5 已增加 `allocation_decisions` 的只读展示页
- 当前可以直接查看 recommendation 列表、详情和原始 JSON
- Phase 3A 已支持从 recommendation 详情页手动执行，并写入 `allocation_tasks` / `trader_positions`
- Phase 4.5 已增加独立 `Portfolio Dashboard` 页面 `/portfolio_dashboard`，聚合展示 trader 净值、盈亏、最近执行和持仓摘要
- `Portfolio Dashboard` 的盈亏口径采用最新价格盯市计算：`最近一次执行后的现金 + 当前持仓按最新快照估值`
- `Portfolio Dashboard` 的趋势图当前基于 `allocation_tasks.portfolio_value` 构建，每个 trader 每天取最后一次执行结果参与总组合聚合
- `Portfolio Dashboard` 同时支持展示每个 trader 自己的收益曲线，数据来源为该 trader 的 `allocation_tasks.portfolio_value`
- Phase 5A 已新增自动 recommendation 生成能力：`GenerateDailyAllocationDecisionsJob` 会为活跃 trader 批量生成 `allocation_decisions`
- Phase 5B 已新增自动 recommendation 执行能力：`ExecuteDailyAllocationDecisionsJob` 会消费当天最新有效 decision，并写入 `allocation_tasks` / `trader_positions` / `trader_trades`
- 自动执行 recommendation 时，若同一 trader 同一天存在多条有效 `allocation_decisions`，默认取 `created_at` 最新的一条
- Phase 5C 已将 recommendation generation / execution 接入 `sidekiq.yml`，当前 cron 顺序为 `signals -> decisions -> execution`
- recommendation 生成层已增加当前持仓上下文输入，LLM 会优先基于现有组合给出调仓建议，而不是默认从空仓重新配置
- recommendation 生成层已新增 `GetCurrentPortfolio` tool，可返回当前现金、持仓、仓位占比、浮盈亏和最近执行摘要
- 已新增 `portfolio_snapshots` 表保存净值历史快照，`Portfolio Dashboard` 曲线将基于快照表而不是 `allocation_tasks` 绘制
- 已新增 `MarkToMarketPortfolioSnapshotsJob`，每天两次按最新价格为活跃 trader 记录 `portfolio_snapshots`
- 已新增 `script/backfill_mark_to_market_snapshots.rb`，可手动回填昨天或指定日期的 `mark_to_market` 快照
- `Portfolio Dashboard` 卡片主数值已优先读取最新 `portfolio_snapshots`，与曲线口径保持一致
- 已新增 `PortfolioSnapshotBackfillService`，可在需要时手动将历史 `allocation_tasks` 回填为快照数据

5. **trading_signals 表**: 可添加 `expiration_time` 字段支持信号有效期管理

### 4.4 索引优化建议

1. 为 `trader_positions(trader_id, market_value)` 建立复合索引支持持仓价值排序
2. 为未来的 `trader_trades(trader_id, executed_at)` 建立复合索引支持交易历史查询
3. 为 `trading_signals(generated_at)` 建立降序索引优化最新信号查询

---

## 5. 版本控制

- **v1.0.0** (2026-03-05): 初始版本，包含核心业务表
- **v1.0.1** (2026-03-06): 优化 assets 表结构，支持多交易所和多数据源
  - 添加 `exchange`, `quote_currency` 字段支持多交易所和计价货币
  - 添加 `coingecko_id`, `yahoo_symbol` 字段对接外部数据源 API
  - 添加 `active` 字段管理资产状态
  - 调整唯一索引为复合索引 `(symbol, exchange, quote_currency)`
- **v1.1.0** (2026-03-13): 新增模拟盘 Phase 1 数据结构
  - 添加 `allocation_decisions` 表保存 LLM 配置建议
  - 添加 `allocation_tasks` 表保存执行任务记录
  - 添加 `trader_positions` 表保存当前持仓
- **v1.1.1** (2026-03-16): 完成模拟盘展示层增强
  - 新增独立 `Portfolio Dashboard` 页面
  - 增加总组合净值/盈亏曲线
  - 增加单个 trader 收益曲线展示
- **v1.1.2** (2026-03-17): 完成 Phase 5A / 5B 自动任务基础能力
  - 新增 recommendation 批量生成 job
  - 新增 recommendation 批量执行 job
- **v1.1.3** (2026-03-17): 完成 Phase 5C 自动调度接入
  - 在 `sidekiq.yml` 中接入 recommendation 生成与执行 cron
- **v1.1.4** (2026-03-17): 新增净值快照层
  - 添加 `portfolio_snapshots` 表
  - 执行 recommendation 后自动写入净值快照
  - `Portfolio Dashboard` 曲线切换到快照表
- **v1.1.5** (2026-03-17): 新增日常盯市快照任务
  - 添加 `MarkToMarketPortfolioSnapshotsJob`
  - 在 `sidekiq.yml` 中接入盯市快照 cron

---

## 6. 维护说明

1. 使用 `rails db:migrate` 管理数据库变更
2. 定期清理旧的 `asset_snapshots` 和 `factor_values` 记录以节省空间
3. 为大表（如 factor_values）考虑分区存储策略
4. 使用只读副本处理分析查询负载
