# SmartTrader 功能模块总览

## 项目信息
- **项目名称:** SmartTrader (智能交易者)
- **Slogan:** Everything is Agent
- **技术栈:** Ruby 4.0.1, Rails 8.1.2, TailwindCSS, Turbo, Stimulus, Claude Code, LLM, Skills, MCP
- **项目目的:** 所以我们可以使用 AI大模型 通过 token 的方式，缩小或磨平和专业机构的信息 认知差异，有AI 操盘手来进行赚钱，有AI分析的交易信号来给出投资建议

---

## 功能模块一览

### 核心功能模块

| 模块 | 名称 | AI技术 | 复杂度 | 优先级 |
|------|------|--------|--------|--------|
| 1 | 操盘手信息管理 | LLM | ⭐⭐ | V1 |
| 2 | 资产动态信息采集 | Skills, MCP | ⭐⭐ | V1 |
| 3 | 操盘手资产管理页面 | LLM | ⭐⭐ | V1 |
| 4 | 市场情绪指数 | Claude Code CLI | ⭐⭐ | V2 |
| 5 | 定时资产配置任务 | LLM, CLI | ⭐⭐⭐ | V1 |
| 6 | 资产配置盈亏排名 | LLM | ⭐⭐ | V2 |
| 7 | 信号广场 | LLM, CLI, Skills | ⭐⭐⭐⭐ | V1 |
| 8 | 交易因子系统 | LLM, Skills | ⭐⭐⭐ | V1 |
| 9 | 策略回测系统 | LLM, Skills | ⭐⭐⭐ | V2 |

### 扩展 Skill 模块

| 模块 | 名称 | AI技术 | 复杂度 | 优先级 |
|------|------|--------|--------|--------|
| 10 | 投资信息 Skill | Skills | ⭐⭐ | V2 |
| 11 | 投资人性格模板 Skill | Skills | ⭐⭐ | V2 |
| 12 | 技术指标解读 Skill | Skills | ⭐ | V2 |

---

## 模块详细说明

### 模块1: 操盘手信息管理 (Trader Profile Management)

**描述:** 创建操盘手信息管理页面，根据一段文字自动生成性格、技术特性以及需要参与配置的资产清单

**AI技术:** LLM (文字解析生成性格特征)

**功能点:**
- 操盘手 CRUD (创建、读取、更新、删除)
- 输入一段文字描述，LLM 自动解析生成：
  - 性格特征
  - 交易风格
  - 风险偏好
  - 建议配置的资产清单

**涉及表:** `traders`, `trader_assets`

---

### 模块2: 资产动态信息采集 (Asset Data Collection)

**描述:** 后台提取资产做后续的调研分析，每天获取资产的动态信息

**AI技术:** MCP (调用外部数据源), Skills (yahoo-finance, ccxt)

**功能点:**
- 资产管理 CRUD 页面
- 后台定时任务采集资产数据：
  - 股票数据 (yahoo-finance)
  - 加密货币数据 (ccxt)
  - 商品数据
- 资产快照历史记录

**涉及表:** `assets`, `asset_snapshots`

---

### 模块3: 操盘手资产管理页面 (Trader Portfolio Dashboard)

**描述:** 显示操盘手的资产盈亏图表

**AI技术:** LLM (生成分析报告)

**功能点:**
- 操盘手投资组合展示
- 持仓列表和详情
- 盈亏图表 (Chart.js)
- AI 生成投资分析报告

**涉及表:** `portfolios`, `portfolio_positions`, `transactions`

---

### 模块4: 市场情绪指数 (Market Sentiment Index)

**描述:** 后台让 Claude Code 打分大盘市场情绪：恐惧贪婪指数，保存到表里

**AI技术:** Claude Code CLI (调用 claude 命令行), LLM

**功能点:**
- 后台定时调用 Claude Code CLI
- AI 分析市场情绪，生成恐惧贪婪指数 (0-100)
- 情绪指数展示页面
- 历史趋势图
- 行业板块情绪分析

**涉及表:** `market_sentiments`, `sector_sentiments`

---

### 模块5: 定时资产配置任务 (Automated Portfolio Allocation)

**描述:** 给操盘手分配10万美元，根据操盘手信息动态调整资产配置

**AI技术:** LLM (决策逻辑), Claude Code CLI

**功能点:**
- 为每个操盘手分配初始资金 ($100,000)
- 定时运行资产配置任务
- LLM 根据操盘手性格 + 市场情绪做出配置决策
- 记录配置决策历史和理由

**涉及表:** `allocation_tasks`, `allocation_decisions`

---

### 模块6: 资产配置盈亏排名 (Portfolio Performance Ranking)

**描述:** 资产配置盈亏排名列表，给出个性化页面

**AI技术:** LLM (生成个性化分析)

**功能点:**
- 所有操盘手盈亏排名列表
- 收益率、夏普比率等指标
- 个性化操盘手页面
- AI 生成个性化表现分析

**涉及表:** `rankings`, `performance_records`

---

### 模块7: 信号广场 (Signal Plaza)

**描述:** 基于交易因子系统，通过AI综合分析生成各类资产（黄金、BTC、英伟达等）的交易信号

**AI技术:** LLM (信号识别), Claude Code CLI, Skills

**复杂度:** ⭐⭐⭐⭐ (高复杂度模块)

**完整流程:**
```
交易因子数据 → AI综合分析 → 信号生成 → 信号存储 → 展示 + 告警
```

**功能点:**

1. **因子数据获取**
   - 从交易因子系统获取多维度因子数据
   - 技术因子、基本面因子、情绪因子、相关性因子
   - 因子综合评分和异常因子识别

2. **AI综合分析**
   - LLM基于多因子数据进行综合分析
   - 识别因子共振和背离情况
   - 结合历史模式和当前市场状态
   - 评估信号可靠性和时效性

3. **信号生成**
   - 买入信号：多因子共振向上突破
   - 卖出信号：多因子共振向下突破
   - 持有信号：因子状态稳定
   - 警告信号：因子异常或背离

4. **信号存储**
   - 信号类型（买入/卖出/持有/警告）
   - 信号强度（强/中/弱）
   - 触发因子组合
   - 置信度和建议持续时间
   - AI分析理由和风险提示

5. **展示 + 告警**
   - 信号广场展示页面（实时信号流）
   - 信号详情（触发因子、历史表现）
   - 实时告警通知（邮件/Webhook）
   - 信号回测和有效性统计

**涉及表:** `trading_signals`, `signal_alerts`, `signal_analysis`

---

### 模块8: 交易因子系统 (Trading Factors System)

**描述:** 构建多维度交易因子体系，通过量化指标和AI分析为交易决策提供数据支持

**AI技术:** LLM (因子解读), Skills (因子计算)

**复杂度:** ⭐⭐⭐

**功能点:**

1. **技术因子**
   - 动量因子：价格动量、成交量动量
   - 波动率因子：历史波动率、隐含波动率
   - 趋势因子：MA趋势、MACD趋势强度
   - 超买超卖因子：RSI、KDJ、布林带位置

2. **基本面因子**
   - 估值因子：PE、PB、PS比率
   - 成长因子：营收增长率、利润增长率
   - 质量因子：ROE、ROA、毛利率
   - 资金流向：大单流入、机构持仓变化

3. **情绪因子**
   - 市场情绪：恐惧贪婪指数
   - 社交媒体热度：讨论量、情感倾向
   - 新闻因子：正面/负面新闻数量
   - 搜索热度：Google Trends、社区关注度

4. **相关性因子**
   - 板块相关性：与行业指数的相关度
   - 市场相关性：Beta系数
   - 跨资产相关性：与黄金、美元等的关联

5. **AI因子合成**
   - LLM综合评分：基于多因子的综合打分
   - 因子权重动态调整
   - 异常因子识别和告警
   - 因子有效性回测

**涉及表:** `trading_factors`, `factor_values`, `factor_scores`

---

### 模块9: 策略回测系统 (Strategy Backtesting System)

**描述:** 使用历史数据验证交易策略的有效性，优化策略参数

**AI技术:** LLM (回测分析), Skills (数据处理)

**复杂度:** ⭐⭐⭐

**优先级:** V2（需要积累足够的历史数据后再实施）

**前置条件:**
- 系统已运行至少1-2个月，积累了足够的历史数据
- 资产快照数据完整（价格、成交量等）
- 因子计算逻辑稳定
- 信号生成逻辑稳定

**功能点:**

1. **回测数据准备**
   - 加载历史资产快照数据
   - 重新计算历史因子数据
   - 生成历史交易信号

2. **回测执行**
   - 模拟交易执行（买入/卖出）
   - 应用策略参数（持仓数、阈值、仓位等）
   - 计算每日持仓和盈亏
   - 记录交易明细

3. **回测指标计算**
   - 总收益率和年化收益率
   - 最大回撤
   - 夏普比率
   - 胜率和盈亏比
   - 交易次数和频率

4. **回测报告生成**
   - 盈亏曲线图
   - 回撤曲线图
   - 交易明细列表
   - LLM 生成回测分析报告
   - 策略优化建议

5. **参数优化**
   - 网格搜索最优参数组合
   - 对比不同参数的回测结果
   - 推荐最优策略参数

**涉及表:** `backtests`, `backtest_trades`, `backtest_metrics`

**数据表结构:**
```ruby
# backtests
- strategy_id (foreign key)
- start_date (date)
- end_date (date)
- initial_capital (decimal)
- final_capital (decimal)
- total_return (decimal)
- max_drawdown (decimal)
- sharpe_ratio (decimal)
- win_rate (decimal)
- status (enum: running, completed, failed)
- created_at (datetime)

# backtest_trades
- backtest_id (foreign key)
- asset_id (foreign key)
- trade_type (enum: buy, sell)
- quantity (decimal)
- price (decimal)
- executed_at (datetime)

# backtest_metrics
- backtest_id (foreign key)
- metric_date (date)
- portfolio_value (decimal)
- cash_balance (decimal)
- daily_return (decimal)
```

---

### 模块10: 投资信息 Skill (Investment Info Skill)

**描述:** 获取投资信息的 skill 用来让后面投资参考，类似 ai-news skill

**AI技术:** Skills (自定义 skill 开发)

**功能点:**
- 获取最新投资相关新闻
- 获取市场分析报告
- 获取特定资产的研究信息
- 可在 Claude Code 中直接调用

**涉及文件:** `skills/investment-news/`

---

### 模块11: 投资人性格模板 Skill (Investor Persona Templates)

**描述:** 收集整理著名投资人的投资风格和策略，形成模板库，用于快速创建名人风格的操盘手

**AI技术:** Skills (模板型 skill 开发)

**功能点:**
- 10+ 位著名投资人模板：
  - 巴菲特、索罗斯、芒格、达里奥、木头姐
  - 彼得·林奇、格雷厄姆、费雪等
- 每位投资人包含：
  - 投资风格和关键词
  - 偏好资产类型
  - 风险偏好
  - 经典策略
  - 名言金句
  - Prompt 模板
- 可在模块1中快速创建名人风格操盘手

**涉及文件:** `skills/investor-personas/`

---

### 模块12: 技术指标解读 Skill (Technical Indicators Skill)

**描述:** 解释常用技术指标的含义和交易信号

**AI技术:** Skills

**功能点:**
- MA/EMA 移动平均线解读
- RSI 超买超卖信号
- MACD 金叉死叉
- 布林带突破信号
- KDJ、成交量等指标

**涉及文件:** `skills/technical-indicators/`

---

## 模块依赖关系

```
模块11 (投资人模板) ──> 模块1 (操盘手) ──> 模块3 (资产管理) ──> 模块6 (盈亏排名)
                                │
模块2 (资产采集) ───────────────┴──> 模块5 (资产配置)
                                │
模块10 (投资Skill) ──> 模块4 (市场情绪) ──> 模块8 (交易因子) ──> 模块7 (信号广场)
                                                                    │
模块2 (资产采集) ──> 模块8 (交易因子) ──────────────────────────> 模块9 (回测系统)
```

**说明:**
- 实线箭头：V1 核心依赖
- 模块9（回测系统）为 V2 功能，依赖于积累的历史数据

---

## 数据表汇总

| 表名 | 说明 | 相关模块 | 优先级 |
|------|------|----------|--------|
| `traders` | 操盘手信息 | 1 | V1 |
| `trader_assets` | 操盘手关联资产 | 1 | V1 |
| `assets` | 资产信息 | 2 | V1 |
| `asset_snapshots` | 资产快照 | 2 | V1 |
| `portfolios` | 投资组合 | 3 | V1 |
| `portfolio_positions` | 持仓明细 | 3 | V1 |
| `transactions` | 交易记录 | 3 | V1 |
| `market_sentiments` | 市场情绪 | 4 | V2 |
| `sector_sentiments` | 行业情绪 | 4 | V2 |
| `allocation_tasks` | 配置任务 | 5 | V1 |
| `allocation_decisions` | 配置决策 | 5 | V1 |
| `rankings` | 排名记录 | 6 | V2 |
| `performance_records` | 业绩记录 | 6 | V2 |
| `trading_signals` | 交易信号 | 7 | V1 |
| `signal_alerts` | 信号告警 | 7 | V2 |
| `trading_factors` | 交易因子定义 | 8 | V1 |
| `factor_values` | 因子数值记录 | 8 | V1 |
| `factor_scores` | 因子综合评分 | 8 | V1 |
| `backtests` | 回测记录 | 9 | V2 |
| `backtest_trades` | 回测交易明细 | 9 | V2 |
| `backtest_metrics` | 回测指标 | 9 | V2 |
