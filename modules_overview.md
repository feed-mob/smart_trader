# SmartTrader 功能模块总览

## 项目信息
- **项目名称:** SmartTrader (智能交易者)
- **Slogan:** Everything is Agent
- **技术栈:** Ruby 4.0.1, Rails 8.1.2, TailwindCSS, Turbo, Stimulus, Claude Code, LLM, Skills, MCP
- **项目目的:** 所以我们可以使用 AI大模型 通过 token 的方式，缩小或磨平和专业机构的信息 认知差异，有AI 操盘手来进行赚钱，有AI分析的交易信号来给出投资建议

---

## 功能模块一览

### 核心功能模块

| 模块 | 名称 | AI技术 | 复杂度 | 推荐人 |
|------|------|--------|--------|--------|
| 1 | 操盘手信息管理 | LLM | ⭐⭐⭐ | Circle |
| 2 | 资产动态信息采集 | Skills, MCP | ⭐⭐⭐ | Jason |
| 3 | 操盘手资产管理页面 | LLM | ⭐⭐ | Circle |
| 4 | 投资信息 Skill | Skills | ⭐⭐⭐ | Jason |
| 5 | 市场情绪指数 | Claude Code CLI | ⭐⭐⭐ | Jason |
| 6 | 定时资产配置任务 | LLM, CLI | ⭐⭐⭐⭐ | Jason |
| 7 | 资产配置盈亏排名 | LLM | ⭐⭐ | Circle |
| 8 | 信号广场 | LLM, CLI, Skills | ⭐⭐⭐⭐⭐ | Jason |
| 9 | 投资人性格模板 Skill | Skills | ⭐⭐ | Holly |

### 低优先级 Skill 模块

| 模块 | 名称 | AI技术 | 复杂度 | 推荐人 |
|------|------|--------|--------|--------|
| 10 | 持仓分析 Skill | Skills | ⭐⭐ | Circle |
| 11 | 技术指标解读 Skill | Skills | ⭐⭐ | Holly |
| 12 | 交易策略模板 Skill | Skills | ⭐⭐ | Jason |

---

## Skill 分配汇总

| 成员 | 核心 Skill | 低优先级 Skill |
|------|-----------|----------------|
| Jason | 模块4: 投资信息 Skill | 模块12: 交易策略模板 Skill |
| Circle | - | 模块10: 持仓分析 Skill |
| Holly | 模块9: 投资人性格模板 Skill | 模块11: 技术指标解读 Skill |

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

### 模块4: 投资信息 Skill (Investment Info Skill)

**描述:** 获取投资信息的 skill 用来让后面投资参考，类似 ai-news skill

**AI技术:** Skills (自定义 skill 开发)

**功能点:**
- 获取最新投资相关新闻
- 获取市场分析报告
- 获取特定资产的研究信息
- 可在 Claude Code 中直接调用

**涉及文件:** `skills/investment-news/`

---

### 模块5: 市场情绪指数 (Market Sentiment Index)

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

### 模块6: 定时资产配置任务 (Automated Portfolio Allocation)

**描述:** 给操盘手分配10万美元，根据操盘手信息动态调整资产配置

**AI技术:** LLM (决策逻辑), Claude Code CLI

**功能点:**
- 为每个操盘手分配初始资金 ($100,000)
- 定时运行资产配置任务
- LLM 根据操盘手性格 + 市场情绪做出配置决策
- 记录配置决策历史和理由

**涉及表:** `allocation_tasks`, `allocation_decisions`

---

### 模块7: 资产配置盈亏排名 (Portfolio Performance Ranking)

**描述:** 资产配置盈亏排名列表，给出个性化页面

**AI技术:** LLM (生成个性化分析)

**功能点:**
- 所有操盘手盈亏排名列表
- 收益率、夏普比率等指标
- 个性化操盘手页面
- AI 生成个性化表现分析

**涉及表:** `rankings`, `performance_records`

---

### 模块8: 信号广场 (Signal Plaza)

**描述:** 大模型分析监控各个资产（黄金、BTC、英伟达）等资产的特殊交易信号

**AI技术:** LLM (信号识别), Claude Code CLI, Skills

**复杂度:** ⭐⭐⭐⭐⭐ (最复杂模块)

**完整流程:**
```
数据采集 → AI 分析 → 信号识别 → 信号存储 → 展示 + 告警
```

**功能点:**

1. **数据采集**
   - 实时/准实时获取资产数据（价格、成交量）
   - 计算技术指标（MA、MACD、RSI、布林带等）
   - 获取相关新闻和市场情绪

2. **AI 分析**
   - LLM 分析多维度数据：技术面、基本面、情绪面
   - 结合历史数据和当前市场状态

3. **信号识别**
   - 技术面信号：突破支撑/阻力、指标金叉/死叉、超买超卖
   - 基本面信号：财报异动、重大新闻
   - 情绪面信号：异常波动、大单异动

4. **信号存储**
   - 信号类型（买入/卖出/持有）
   - 信号强度（强/中/弱）
   - 置信度和时效性
   - AI 分析理由

5. **展示 + 告警**
   - 信号广场展示页面
   - 实时告警通知（邮件/Webhook）

**涉及表:** `trading_signals`, `signal_alerts`, `signal_analysis`

---

### 模块9: 投资人性格模板 Skill (Investor Persona Templates)

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

### 模块10: 持仓分析 Skill (Portfolio Analysis Skill)

**描述:** 分析投资组合的风险、集中度、相关性，给出调整建议

**AI技术:** Skills

**优先级:** 低

**功能点:**
- 分析持仓集中度
- 计算组合风险指标
- 资产相关性分析
- 给出再平衡建议

**涉及文件:** `skills/portfolio-analysis/`

---

### 模块11: 技术指标解读 Skill (Technical Indicators Skill)

**描述:** 解释常用技术指标的含义和交易信号

**AI技术:** Skills

**优先级:** 低

**功能点:**
- MA/EMA 移动平均线解读
- RSI 超买超卖信号
- MACD 金叉死叉
- 布林带突破信号
- KDJ、成交量等指标

**涉及文件:** `skills/technical-indicators/`

---

### 模块12: 交易策略模板 Skill (Trading Strategy Templates Skill)

**描述:** 常见交易策略的模板和说明

**AI技术:** Skills

**优先级:** 低

**功能点:**
- 网格交易策略
- 定投策略
- 动量策略
- 均值回归策略
- 趋势跟踪策略

**涉及文件:** `skills/trading-strategies/`

---

## 模块依赖关系

```
模块9 (投资人模板) ──> 模块1 (操盘手) ──> 模块3 (资产管理) ──> 模块7 (盈亏排名)
                                │
模块2 (资产采集) ───────────────┴──> 模块6 (资产配置)
                                │
模块4 (投资Skill) ──> 模块5 (市场情绪) ──> 模块8 (信号广场)
```

---

## 数据表汇总

| 表名 | 说明 | 相关模块 |
|------|------|----------|
| `traders` | 操盘手信息 | 1 |
| `trader_assets` | 操盘手关联资产 | 1 |
| `assets` | 资产信息 | 2 |
| `asset_snapshots` | 资产快照 | 2 |
| `portfolios` | 投资组合 | 3 |
| `portfolio_positions` | 持仓明细 | 3 |
| `transactions` | 交易记录 | 3 |
| `market_sentiments` | 市场情绪 | 5 |
| `sector_sentiments` | 行业情绪 | 5 |
| `allocation_tasks` | 配置任务 | 6 |
| `allocation_decisions` | 配置决策 | 6 |
| `rankings` | 排名记录 | 7 |
| `performance_records` | 业绩记录 | 7 |
| `trading_signals` | 交易信号 | 8 |
| `signal_alerts` | 信号告警 | 8 |
