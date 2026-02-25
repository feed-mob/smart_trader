# SmartTrader MVP v1.0 计划

## 目标
第一次迭代，跑通完整流程：创建操盘手 → 采集数据 → 计算因子 → 生成信号 → 资产配置 → 查看盈亏

---

## 核心流程

```
操盘手创建 → 策略配置 → 资产数据采集 → 交易因子计算 → 信号生成 → 策略执行 → 盈亏展示
   (模块1)    (模块2)      (模块3)         (模块4)        (模块5)     (模块6)    (模块7)
```

---

## MVP 模块清单

### 模块1: 操盘手管理（简化版）

**目标:** 快速创建操盘手，设置基本属性

**功能:**
- [ ] 操盘手 CRUD 页面
- [ ] 基本字段：
  - 名称
  - 风险偏好（保守/平衡/激进）
  - 初始资金（固定 $100,000）
  - 状态（启用/停用）
- 需要 LLM 解析，手动选择风格

**数据表:**
```ruby
# traders
- name (string)
- risk_level (enum: conservative, balanced, aggressive)
- strategy_id (foreign key)
- initial_capital (decimal, default: 100000)
- current_capital (decimal)
- status (enum: active, inactive)
```

---

### 模块2: LLM 策略生成（核心功能）

**目标:** 根据操盘手描述，LLM 动态生成个性化交易策略

**策略生成时机:**
- **操盘手创建时**: 用户输入描述 → LLM 分析 → 生成策略参数 → 创建策略

**功能:**
- [ ] 操盘手创建表单包含"投资风格描述"字段（文本框）
- [ ] 调用 LLM API 分析描述，生成策略参数
- [ ] LLM 返回结构化的策略配置
- [ ] 自动创建个性化策略并关联到操盘手
- [ ] 策略可以后续修改（重新生成或手动调整）

**LLM 策略生成 Prompt:**
```
你是一位专业的投资顾问。根据以下投资者的描述，生成一套适合的交易策略参数。

投资者描述：
"{用户输入的描述}"

请分析投资者的风险偏好、投资目标和交易风格，生成以下参数：

1. 策略名称（简短描述，如"稳健价值投资策略"）
2. 风险等级（conservative/balanced/aggressive）
3. 最大持仓数（2-5个资产）
4. 买入信号阈值（0.3-0.7，数值越高越严格）
5. 单个资产最大仓位（30%-70%）
6. 最小现金保留比例（5%-40%）
7. 策略说明（1-2句话）

返回 JSON 格式：
{
  "name": "策略名称",
  "risk_level": "conservative|balanced|aggressive",
  "max_positions": 3,
  "buy_signal_threshold": 0.5,
  "max_position_size": 0.5,
  "min_cash_reserve": 0.2,
  "description": "策略说明"
}

注意：
- 参数必须在合理范围内
- 保守型投资者：持仓少、阈值高、仓位小、现金多
- 激进型投资者：持仓多、阈值低、仓位大、现金少
```

**备选方案（LLM 失败时）:**
- [ ] 系统预设3种默认策略模板作为备选
- [ ] 如果 LLM 调用失败，使用默认策略
- [ ] 用户可以手动选择默认策略

**数据表:**
```ruby
# trading_strategies
- trader_id (foreign key, unique) # 每个操盘手一个策略
- name (string, e.g., "稳健价值投资策略")
- risk_level (enum: conservative, balanced, aggressive)
- max_positions (integer, 2-5)
- buy_signal_threshold (decimal, 0.3-0.7)
- max_position_size (decimal, 0.3-0.7)
- min_cash_reserve (decimal, 0.05-0.4)
- description (text)
- generated_by (enum: llm, manual, default)
- created_at (datetime)
```

**示例描述和生成结果:**

输入描述：
> "我是一个稳健型投资者，注重长期价值投资，不喜欢频繁交易。我希望在保护本金的前提下获得稳定收益，可以接受适度的波动。"

LLM 生成：
```json
{
  "name": "稳健价值投资策略",
  "risk_level": "conservative",
  "max_positions": 2,
  "buy_signal_threshold": 0.6,
  "max_position_size": 0.4,
  "min_cash_reserve": 0.3,
  "description": "注重本金保护，持仓集中，严格筛选买入信号，保留充足现金应对波动"
}
```

输入描述：
> "我是激进型交易者，追求高收益，能承受较大风险。我喜欢抓住市场机会，快速进出。"

LLM 生成：
```json
{
  "name": "激进成长策略",
  "risk_level": "aggressive",
  "max_positions": 4,
  "buy_signal_threshold": 0.4,
  "max_position_size": 0.6,
  "min_cash_reserve": 0.1,
  "description": "追求高收益，分散持仓，积极捕捉机会，保持高仓位运作"
}
```

---

### 模块3: 资产数据采集（简化版）

**目标:** 采集少量核心资产的实时数据

**功能:**
- [ ] 固定资产池（不需要 CRUD）：
  - BTC (加密货币)
  - ETH (加密货币)
  - AAPL (股票)
  - NVDA (股票)
  - GLD (黄金 ETF)
- [ ] 后台任务每小时采集一次
- [ ] 使用 yahoo-finance skill 获取数据
- [ ] 存储：价格、涨跌幅、成交量

**数据表:**
```ruby
# assets (固定5个资产，seed data)
- symbol (string, e.g., "BTC", "AAPL")
- name (string)
- asset_type (enum: crypto, stock, commodity)

# asset_snapshots
- asset_id (foreign key)
- price (decimal)
- change_percent (decimal)
- volume (decimal)
- captured_at (datetime)
```

---

### 模块4: 交易因子计算（简化版）

**目标:** 计算3个核心因子

**功能:**
- [ ] 每小时计算一次（跟随数据采集）
- [ ] 只计算3个因子：
  1. **动量因子**: 24小时涨跌幅
  2. **波动率因子**: 24小时价格波动率
  3. **情绪因子**: 简化版恐惧贪婪指数（基于涨跌幅分布）
- [ ] 每个因子评分 -1 到 +1
- [ ] 综合评分 = 三个因子的加权平均

**数据表:**
```ruby
# factor_values
- asset_id (foreign key)
- factor_type (enum: momentum, volatility, sentiment)
- value (decimal, -1 to 1)
- calculated_at (datetime)

# factor_scores
- asset_id (foreign key)
- composite_score (decimal, -1 to 1)
- calculated_at (datetime)
```

---

### 模块5: 信号生成（简化版）

**目标:** 基于因子评分生成简单信号

**功能:**
- [ ] 每小时生成一次信号
- [ ] 简单规则（不用 LLM）：
  - 综合评分 > 0.5 → 买入信号
  - 综合评分 < -0.5 → 卖出信号
  - -0.5 到 0.5 → 持有信号
- [ ] 信号强度 = abs(综合评分)
- [ ] 只保留最新信号

**数据表:**
```ruby
# trading_signals
- asset_id (foreign key)
- signal_type (enum: buy, sell, hold)
- strength (decimal, 0 to 1)
- composite_score (decimal)
- generated_at (datetime)
```

---

### 模块6: 策略执行与资产配置（简化版）

**目标:** 根据操盘手的策略和信号执行资产配置

**功能:**
- [ ] 每天运行一次（每天收盘后）
- [ ] 策略驱动的配置逻辑：
  1. 获取操盘手的策略参数
  2. 筛选符合策略阈值的买入信号
  3. 按信号强度排序，选择前N个资产（N = max_positions）
  4. 计算每个资产的配置比例：
     - 基础比例 = 信号强度 / 总强度
     - 限制单个资产不超过 max_position_size
     - 保留 min_cash_reserve 的现金
  5. 执行买入/卖出操作
  6. 记录配置决策和理由
- [ ] 卖出逻辑：
  - 持仓资产出现卖出信号 → 清仓
  - 持仓资产不在新的买入列表中 → 清仓

**数据表:**
```ruby
# portfolios
- trader_id (foreign key)
- total_value (decimal)
- cash_balance (decimal)
- updated_at (datetime)

# portfolio_positions
- portfolio_id (foreign key)
- asset_id (foreign key)
- quantity (decimal)
- avg_cost (decimal)
- current_value (decimal)
- profit_loss (decimal)
- profit_loss_percent (decimal)

# allocation_decisions
- trader_id (foreign key)
- strategy_id (foreign key)
- decision_data (jsonb) # 记录配置详情和策略参数
- signals_used (jsonb) # 使用的信号
- executed_at (datetime)
```

---

### 模块7: 盈亏展示（简化版）

**目标:** 展示操盘手的资产和盈亏情况

**功能:**
- [ ] 操盘手详情页面
- [ ] 显示：
  - 当前使用的策略信息
  - 当前总资产
  - 总盈亏金额和百分比
  - 持仓列表（资产、数量、成本、当前价值、盈亏）
  - 现金余额和现金比例
  - 最近的配置决策记录
- [ ] 简单的盈亏曲线图（Chart.js）
- [ ] 策略执行统计（持仓数、现金比例等）

**页面:** `traders/:id/portfolio`

---

## 技术实现要点

### 后台任务

```ruby
# 每小时执行
class HourlyDataPipeline
  def perform
    CollectAssetDataJob.perform_now      # 采集数据
    CalculateFactorsJob.perform_now      # 计算因子
    GenerateSignalsJob.perform_now       # 生成信号
  end
end

# 每天执行
class DailyAllocationJob
  def perform
    Trader.active.each do |trader|
      strategy = trader.trading_strategy
      AllocatePortfolioService.new(trader, strategy).execute
    end
  end
end
```

### Skills 使用

- **yahoo-finance**: 获取股票和 ETF 数据
- **ccxt**: 获取加密货币数据

### LLM 集成

- **API**: Anthropic Claude API
- **模型**: Claude Sonnet 4.6（策略生成）
- **用途**:
  - 策略参数生成
  - 策略描述优化
- **备选**: 如果 API 调用失败，使用默认策略模板

### 不使用的功能（V1暂不实现）

- ❌ LLM 解析操盘手性格
- ❌ 投资人性格模板
- ❌ 市场情绪指数（独立模块）
- ❌ 复杂的技术指标
- ❌ 基本面因子
- ❌ 信号告警通知
- ❌ 排名系统
- ❌ 交易记录详情

---

## 开发顺序

### Phase 1: 基础架构（1-2天）
1. [ ] 创建数据表 migrations
2. [ ] 创建 models 和基本关联
3. [ ] 设置 Sidekiq 后台任务
4. [ ] Seed 5个固定资产
5. [ ] Seed 3种默认策略模板（备选）
6. [ ] 配置 LLM API（Anthropic Claude）

### Phase 2: LLM 策略生成（1-2天）
7. [ ] 实现 StrategyGeneratorService
8. [ ] 设计和测试 LLM Prompt
9. [ ] 实现 JSON 解析和参数验证
10. [ ] 实现备选方案（LLM 失败时使用默认策略）
11. [ ] 测试不同描述的策略生成效果

### Phase 3: 数据采集（1天）
12. [ ] 实现 CollectAssetDataJob
13. [ ] 集成 yahoo-finance 和 ccxt skills
14. [ ] 测试数据采集和存储

### Phase 4: 因子和信号（1-2天）
15. [ ] 实现 CalculateFactorsJob（3个因子）
16. [ ] 实现 GenerateSignalsJob（简单规则）
17. [ ] 测试因子计算和信号生成

### Phase 5: 策略执行（2天）
18. [ ] 实现 AllocatePortfolioService（策略驱动）
19. [ ] 实现策略参数应用逻辑
20. [ ] 实现买入/卖出执行逻辑
21. [ ] 测试不同策略的配置效果

### Phase 6: 前端展示（1-2天）
22. [ ] 操盘手 CRUD 页面（含描述输入和策略展示）
23. [ ] 策略生成预览功能
24. [ ] 操盘手详情页（持仓、盈亏、策略信息）
25. [ ] 简单的盈亏曲线图
26. [ ] 信号列表页面（可选）

### Phase 7: 集成测试（1天）
27. [ ] 端到端测试完整流程
28. [ ] 测试不同描述生成的策略表现
29. [ ] 修复 bugs
30. [ ] 优化性能

**预计总时间: 9-12天**

---

## 验收标准

✅ 能够创建操盘手并选择交易策略
✅ 3种策略模板正常工作（保守/平衡/激进）
✅ 后台自动采集5个资产的数据
✅ 自动计算因子和生成信号
✅ 每天根据策略自动调整资产配置
✅ 不同策略产生不同的持仓结构
✅ 前端能看到持仓、盈亏和策略信息
✅ 系统运行7天后，能看到盈亏变化曲线
✅ 能对比不同策略的表现差异

---

## 下一步迭代（V2）可以加入

- 更多资产类型
- 更复杂的因子（RSI、MACD等）
- 自定义策略参数
- 策略回测功能
- LLM 动态策略调整
- 市场情绪指数
- 信号告警
- 多操盘手排名
- 投资人性格模板
- 策略优化建议
