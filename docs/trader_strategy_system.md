# SmartTrader 操盘手与策略系统

## 项目概述

SmartTrader 操盘手与策略系统是平台的核心基础模块，实现了 AI 操盘手管理和智能策略生成功能。每个操盘手拥有针对不同市场环境的个性化交易策略。

---

## 一、核心概念

### 1.1 操盘手 (Trader)

AI 操盘手是 SmartTrader 的核心实体，代表一个独立的投资决策单元。

```
操盘手属性：
├── 基本信息: 名称、描述
├── 风险偏好: conservative / balanced / aggressive
├── 资金: 初始资金、当前资金
├── 状态: active / inactive
└── 策略: 4种市场环境 × 1套策略参数
```

### 1.2 交易策略 (TradingStrategy)

每个操盘手拥有 4 套策略，对应不同的市场环境：

| 市场环境 | 英文代码 | 描述 |
|---------|---------|------|
| 正常市场 | `normal` | 市场稳定运行，波动适中 |
| 高波动市场 | `volatile` | 价格剧烈波动，不确定性高 |
| 崩盘市场 | `crash` | 价格大幅下跌，恐慌情绪蔓延 |
| 泡沫市场 | `bubble` | 价格非理性上涨，估值过高 |

### 1.3 策略参数说明

| 参数 | 范围 | 含义 |
|------|------|------|
| `max_positions` | 2-5 | 最大持仓资产数量 |
| `buy_signal_threshold` | 0.3-0.7 | 买入信号阈值（越高越严格） |
| `max_position_size` | 0.3-0.7 | 单资产最大仓位比例 |
| `min_cash_reserve` | 0.05-0.4 | 最小现金保留比例 |

---

## 二、策略矩阵系统

### 2.1 矩阵设计理念

系统预设 12 种策略（3 种风险等级 × 4 种市场环境），作为 LLM 生成失败时的备选方案。

```
                    正常市场    高波动市场   崩盘市场    泡沫市场
                    ─────────────────────────────────────────
保守型 (conservative)   稳健配置     减仓观望     防守保本     获利了结
平衡型 (balanced)       均衡配置     适度防御     小幅抄底     逐步减仓
激进型 (aggressive)     积极成长     波段操作     逆向买入     趋势跟随
```

### 2.2 策略矩阵详情

#### 正常市场 (normal)

| 风险等级 | 策略名称 | 持仓数 | 买入阈值 | 最大仓位 | 现金保留 |
|---------|---------|--------|---------|---------|---------|
| 保守型 | 稳健配置策略 | 2 | 0.60 | 40% | 30% |
| 平衡型 | 均衡配置策略 | 3 | 0.50 | 50% | 20% |
| 激进型 | 积极成长策略 | 4 | 0.40 | 60% | 10% |

#### 高波动市场 (volatile)

| 风险等级 | 策略名称 | 持仓数 | 买入阈值 | 最大仓位 | 现金保留 |
|---------|---------|--------|---------|---------|---------|
| 保守型 | 减仓观望策略 | 2 | 0.65 | 30% | 40% |
| 平衡型 | 适度防御策略 | 3 | 0.55 | 40% | 30% |
| 激进型 | 波段操作策略 | 4 | 0.45 | 50% | 20% |

#### 崩盘市场 (crash)

| 风险等级 | 策略名称 | 持仓数 | 买入阈值 | 最大仓位 | 现金保留 |
|---------|---------|--------|---------|---------|---------|
| 保守型 | 防守保本策略 | 2 | 0.70 | 25% | 50% |
| 平衡型 | 小幅抄底策略 | 3 | 0.50 | 40% | 30% |
| 激进型 | 逆向买入策略 | 5 | 0.35 | 65% | 5% |

#### 泡沫市场 (bubble)

| 风险等级 | 策略名称 | 持仓数 | 买入阈值 | 最大仓位 | 现金保留 |
|---------|---------|--------|---------|---------|---------|
| 保守型 | 获利了结策略 | 2 | 0.70 | 30% | 45% |
| 平衡型 | 逐步减仓策略 | 3 | 0.60 | 40% | 35% |
| 激进型 | 趋势跟随策略 | 4 | 0.40 | 55% | 15% |

---

## 三、LLM 策略生成

### 3.1 生成时机

```
操盘手创建/更新
       │
       ├── 用户输入投资风格描述
       │
       ↓
StrategyGeneratorService
       │
       ├── 有描述? ──→ LLM 生成 4 套策略
       │                (generated_by: :llm)
       │
       └── 无描述? ──→ 使用策略矩阵
                        (generated_by: :matrix)
```

### 3.2 LLM Prompt 设计

**System Instructions:**
```
你是一位专业的投资顾问。根据投资者的风险偏好和市场环境，生成适合的交易策略参数。

市场环境说明：
- normal: 正常市场环境，稳定运行
- volatile: 高波动市场，价格剧烈波动
- crash: 崩盘市场，价格大幅下跌
- bubble: 泡沫市场，价格非理性上涨

风险偏好说明：
- conservative: 保守型，注重本金安全
- balanced: 平衡型，平衡风险与收益
- aggressive: 激进型，追求高收益
```

**User Prompt 示例:**
```
投资者描述：
"我是一个稳健型投资者，注重长期价值投资，不喜欢频繁交易。我希望在保护本金的前提下获得稳定收益。"

风险偏好：conservative
市场环境：normal

返回 JSON 格式：
{"name":"策略名称","max_positions":3,"buy_signal_threshold":0.5,"max_position_size":0.5,"min_cash_reserve":0.2,"description":"策略说明"}
```

### 3.3 生成结果示例

**输入描述：**
> "我是一个稳健型投资者，注重长期价值投资，不喜欢频繁交易。我希望在保护本金的前提下获得稳定收益，可以接受适度的波动。"

**LLM 生成（正常市场）：**
```json
{
  "name": "稳健价值投资策略",
  "max_positions": 2,
  "buy_signal_threshold": 0.60,
  "max_position_size": 0.40,
  "min_cash_reserve": 0.30,
  "description": "注重本金保护，持仓集中，严格筛选买入信号，保留充足现金应对波动"
}
```

**输入描述：**
> "我是激进型交易者，追求高收益，能承受较大风险。我喜欢抓住市场机会，快速进出。"

**LLM 生成（正常市场）：**
```json
{
  "name": "激进成长策略",
  "max_positions": 4,
  "buy_signal_threshold": 0.40,
  "max_position_size": 0.60,
  "min_cash_reserve": 0.10,
  "description": "追求高收益，分散持仓，积极捕捉机会，保持高仓位运作"
}
```

---

## 四、数据结构

### 4.1 traders 表

```ruby
create_table :traders do |t|
  t.string :name, null: false                    # 操盘手名称
  t.text :description                            # 投资风格描述
  t.integer :risk_level, default: 0              # 0=保守, 1=平衡, 2=激进
  t.decimal :initial_capital, precision: 15, scale: 2  # 初始资金
  t.decimal :current_capital, precision: 15, scale: 2 # 当前资金
  t.integer :status, default: 0                  # 0=启用, 1=停用

  t.timestamps
end
```

### 4.2 trading_strategies 表

```ruby
create_table :trading_strategies do |t|
  t.references :trader, null: false, foreign_key: true
  t.string :name, null: false                    # 策略名称
  t.text :description                            # 策略说明
  t.integer :risk_level, default: 1              # 风险等级
  t.integer :max_positions, default: 3           # 最大持仓数 (2-5)
  t.decimal :buy_signal_threshold, precision: 3, scale: 2  # 买入阈值 (0.3-0.7)
  t.decimal :max_position_size, precision: 3, scale: 2     # 最大仓位 (0.3-0.7)
  t.decimal :min_cash_reserve, precision: 3, scale: 2      # 现金保留 (0.05-0.4)
  t.integer :market_condition, default: 0        # 市场环境
  t.integer :generated_by, default: 0            # 生成方式

  t.timestamps
end

add_index :trading_strategies, [:trader_id, :market_condition], unique: true
```

### 4.3 关联关系

```
User
  └── has_many :traders

Trader
  ├── belongs_to :user
  └── has_many :trading_strategies

TradingStrategy
  └── belongs_to :trader
```

---

## 五、业务流程

### 5.1 创建操盘手流程

```
┌─────────────────────────────────────────────────────────────────────┐
│                     操盘手创建流程                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. 用户填写表单                                                     │
│     ┌──────────────┐                                                │
│     │ 名称         │                                                │
│     │ 风险等级     │                                                │
│     │ 初始资金     │                                                │
│     │ 投资风格描述  │  ←── 关键输入，用于 LLM 策略生成                │
│     └──────────────┘                                                │
│              │                                                      │
│              ↓                                                      │
│  2. TradersController#create                                        │
│     ┌──────────────────────────────────────┐                        │
│     │ @trader = Trader.new(trader_params)   │                        │
│     │ @trader.save                          │                        │
│     │ generate_strategies_for(@trader)      │                        │
│     └──────────────────────────────────────┘                        │
│              │                                                      │
│              ↓                                                      │
│  3. StrategyGeneratorService#generate_strategies                    │
│     ┌──────────────────────────────────────┐                        │
│     │ 遍历 4 种市场环境:                     │                        │
│     │   normal, volatile, crash, bubble     │                        │
│     │                                        │                        │
│     │ 每种环境:                              │                        │
│     │   有描述 → LLM 生成                    │                        │
│     │   无描述 → 策略矩阵                    │                        │
│     └──────────────────────────────────────┘                        │
│              │                                                      │
│              ↓                                                      │
│  4. 创建 4 条 TradingStrategy 记录                                   │
│     ┌──────────────────────────────────────┐                        │
│     │ trader.trading_strategies.create(...) │ × 4                   │
│     └──────────────────────────────────────┘                        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 更新操盘手流程

```
用户修改描述或风险等级
         │
         ↓
检测 saved_change_to_description? || saved_change_to_risk_level?
         │
         ├── true ──→ 销毁旧策略 → 重新生成 4 套策略
         │
         └── false ──→ 保持原策略不变
```

---

## 六、服务层架构

### 6.1 AiChatService

封装 LLM 调用，基于 RubyLLM gem。

```ruby
class AiChatService
  MODEL = "claude-sonnet-4-6"
  PROVIDER = :openai

  def initialize(instructions: nil, temperature: 0.3, max_tokens: 1000)
    # ...
  end

  def ask(prompt)
    chat = RubyLLM.chat(model: MODEL, provider: PROVIDER)
    chat.with_instructions(@instructions) if @instructions.present?
    chat.ask(prompt).content
  end
end
```

### 6.2 StrategyGeneratorService

核心策略生成服务。

```ruby
class StrategyGeneratorService
  def initialize(description, risk_level: nil)
    @description = description
    @risk_level = risk_level
  end

  # 生成所有 4 种市场环境的策略
  def generate_strategies
    if @description.present?
      generate_all_with_ai    # LLM 生成
    else
      fallback_strategies     # 策略矩阵
    end
  end

  private

  def generate_single_strategy_with_ai(market_condition)
    # 调用 AiChatService，解析 JSON 响应
  end

  def fallback_strategies
    # 从 STRATEGY_MATRIX 获取预设策略
  end
end
```

---

## 七、页面设计

### 7.1 操盘手列表页面

```
┌─────────────────────────────────────────────────────────────────────┐
│  操盘手管理                                    [+ 新建操盘手]         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 巴菲特风格                                     [编辑] [删除]  │   │
│  │ ───────────────────────────────────────────────────────────  │   │
│  │ 风险等级: 保守型    初始资金: ¥100,000    状态: 启用         │   │
│  │ 当前资金: ¥105,230  收益率: +5.23%                          │   │
│  │ 策略: AI 生成 (4套)                                          │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 索罗斯风格                                     [编辑] [删除]  │   │
│  │ ───────────────────────────────────────────────────────────  │   │
│  │ 风险等级: 激进型    初始资金: ¥100,000    状态: 启用         │   │
│  │ 当前资金: ¥112,450  收益率: +12.45%                         │   │
│  │ 策略: AI 生成 (4套)                                          │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.2 操盘手创建/编辑表单

```
┌─────────────────────────────────────────────────────────────────────┐
│  新建操盘手                                                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  名称 *                                                             │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 例如：巴菲特风格                                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│  给操盘手起个名字，便于识别                                          │
│                                                                     │
│  风险等级 *                                                         │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 保守型 - 注重本金保护                                     ▼  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│  选择操盘手的风险偏好                                                │
│                                                                     │
│  初始资金 *                                                         │
│  ┌───┬─────────────────────────────────────────────────────────┐   │
│  │ ¥ │ 100,000                                                  │   │
│  └───┴─────────────────────────────────────────────────────────┘   │
│  操盘手的起始资金（默认 ¥100,000）                                   │
│                                                                     │
│  投资风格描述                                                        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 描述您的投资风格，例如：                                      │   │
│  │ 我是稳健型投资者，注重长期价值投资。                          │   │
│  │ 我喜欢持有优质蓝筹股，追求稳定的分红收益。                    │   │
│  │ 我会严格控制仓位，保留足够的现金应对市场波动。                │   │
│  │                                                               │   │
│  └─────────────────────────────────────────────────────────────┘   │
│  ⓘ AI 将根据描述自动生成个性化的交易策略。描述越详细，策略越精准。   │
│                                                                     │
│  [创建操盘手]  [取消]                                                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.3 操盘手详情页面

```
┌─────────────────────────────────────────────────────────────────────┐
│  ← 返回列表                    巴菲特风格                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  基本信息                              [编辑] [删除]                 │
│  ─────────────────────────────────────────────────────────────────  │
│  风险等级: 保守型                                                   │
│  初始资金: ¥100,000                                                 │
│  当前资金: ¥105,230                                                 │
│  总收益:   +¥5,230 (+5.23%)                                         │
│  状态:     启用                                                     │
│                                                                     │
│  投资风格描述                                                        │
│  ─────────────────────────────────────────────────────────────────  │
│  "我是稳健型投资者，注重长期价值投资，不喜欢频繁交易。               │
│   我希望在保护本金的前提下获得稳定收益，可以接受适度的波动。"         │
│                                                                     │
│  交易策略 (4套)                                                      │
│  ─────────────────────────────────────────────────────────────────  │
│                                                                     │
│  ┌─────────────────────┐  ┌─────────────────────┐                   │
│  │ 正常市场             │  │ 高波动市场           │                   │
│  │ 稳健配置策略         │  │ 减仓观望策略         │                   │
│  │ AI 生成              │  │ AI 生成              │                   │
│  │                     │  │                     │                   │
│  │ 持仓: 2  阈值: 0.60  │  │ 持仓: 2  阈值: 0.65  │                   │
│  │ 仓位: 40% 现金: 30%  │  │ 仓位: 30% 现金: 40%  │                   │
│  └─────────────────────┘  └─────────────────────┘                   │
│                                                                     │
│  ┌─────────────────────┐  ┌─────────────────────┐                   │
│  │ 崩盘市场             │  │ 泡沫市场             │                   │
│  │ 防守保本策略         │  │ 获利了结策略         │                   │
│  │ AI 生成              │  │ AI 生成              │                   │
│  │                     │  │                     │                   │
│  │ 持仓: 2  阈值: 0.70  │  │ 持仓: 2  阈值: 0.70  │                   │
│  │ 仓位: 25% 现金: 50%  │  │ 仓位: 30% 现金: 45%  │                   │
│  └─────────────────────┘  └─────────────────────┘                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 八、实施状态

### 8.1 已完成功能

| 序号 | 功能 | 状态 |
|------|------|------|
| 1 | Trader 模型 + Migration | ✅ 完成 |
| 2 | TradingStrategy 模型 + Migration | ✅ 完成 |
| 3 | 策略矩阵 (12种预设策略) | ✅ 完成 |
| 4 | AiChatService (LLM 封装) | ✅ 完成 |
| 5 | StrategyGeneratorService | ✅ 完成 |
| 6 | 操盘手 CRUD 页面 | ✅ 完成 |
| 7 | 策略自动生成 (4套/操盘手) | ✅ 完成 |
| 8 | 描述更新时策略重新生成 | ✅ 完成 |

### 8.2 待扩展功能 (V2)

| 功能 | 说明 | 优先级 |
|------|------|--------|
| 策略手动微调 | 用户可调整 LLM 生成的参数 | 高 |
| 策略预览 | 创建前预览 AI 生成的策略 | 中 |
| 策略对比 | 对比不同操盘手的策略差异 | 中 |
| 策略回测 | 用历史数据验证策略效果 | 低 |
| 多语言支持 | 支持英文策略生成 | 低 |

---

## 九、API 接口

### 9.1 RESTful API

```
GET    /traders           # 操盘手列表
GET    /traders/:id       # 操盘手详情
POST   /traders           # 创建操盘手（自动生成策略）
PATCH  /traders/:id       # 更新操盘手（可能重新生成策略）
DELETE /traders/:id       # 删除操盘手
```

### 9.2 创建操盘手请求示例

```json
POST /traders
{
  "trader": {
    "name": "巴菲特风格",
    "risk_level": "conservative",
    "initial_capital": 100000,
    "description": "我是稳健型投资者，注重长期价值投资..."
  }
}
```

### 9.3 响应示例

```json
{
  "id": 1,
  "name": "巴菲特风格",
  "risk_level": "conservative",
  "initial_capital": "100000.00",
  "current_capital": "100000.00",
  "status": "active",
  "trading_strategies": [
    {
      "id": 1,
      "name": "稳健配置策略",
      "market_condition": "normal",
      "max_positions": 2,
      "buy_signal_threshold": "0.6",
      "max_position_size": "0.4",
      "min_cash_reserve": "0.3",
      "generated_by": "llm"
    },
    // ... 其他 3 套策略
  ]
}
```

---

## 十、技术栈

| 模块 | 技术 |
|------|------|
| Web 框架 | Rails 8.1 |
| 数据库 | PostgreSQL |
| LLM | Claude Sonnet 4.6 (via RubyLLM) |
| 前端 | Turbo + Stimulus |
| CSS | Tailwind CSS |
| 认证 | Google Sign-In |

---

## 十一、AI 驱动的策略微调（待实现）

> 本章节描述如何利用交易因子系统，在交易执行时通过 AI 动态微调策略参数。

### 11.1 设计理念

当前策略在操盘手创建时生成，是"静态"的。通过引入因子系统，可以在交易时根据市场状态动态调整策略参数，实现"静态策略 + 动态微调"的混合模式。

```
┌─────────────────────────────────────────────────────────────────────┐
│                     AI 交易决策流程                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  基础策略（创建时生成）          因子数据（每小时计算）                │
│  ┌──────────────┐          ┌──────────────┐                        │
│  │ 保守型策略    │          │ 动量:   +0.65 │                        │
│  │ max_pos: 2   │          │ 波动率: -0.15 │                        │
│  │ threshold:0.6│   +      │ 成交量: +0.45 │                        │
│  │ ...         │          │ ...          │                        │
│  └──────────────┘          └──────────────┘                        │
│           │                        │                                │
│           └──────────┬─────────────┘                                │
│                      ↓                                              │
│              ┌──────────────────┐                                   │
│              │     LLM 分析     │  ← AI 综合分析                     │
│              │                  │                                   │
│              │  输入：策略 + 因子 │                                   │
│              │  输出：调整后参数  │                                   │
│              │       + 决策理由  │                                   │
│              └──────────────────┘                                   │
│                      │                                              │
│                      ↓                                              │
│              ┌──────────────────┐                                   │
│  调整后策略  │ max_pos: 2       │                                   │
│  + AI 理由   │ threshold: 0.55  │                                   │
│              │ 理由: "动量强劲   │                                   │
│              │ 且成交量放大，    │                                   │
│              │ 建议适度降门槛"   │                                   │
│              └──────────────────┘                                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 11.2 LLM Prompt 设计

**System Prompt:**
```
你是一位专业的量化交易策略师。你的任务是根据当前市场因子数据，动态调整交易策略参数。

## 基础策略参数说明
- max_positions: 最大持仓数量 (2-5)
- buy_signal_threshold: 买入信号阈值 (0.3-0.7)，越高越严格
- max_position_size: 单资产最大仓位 (0.3-0.7)
- min_cash_reserve: 最小现金保留 (0.05-0.4)

## 因子说明
- momentum: 动量因子 (-1 到 +1)，正值表示上涨趋势
- volatility: 波动率因子 (-1 到 +1)，负值表示低波动（好）
- beta: 贝塔因子 (-1 到 +1)，接近 0 表示与市场同步
- volume_ratio: 成交量比率 (-1 到 +1)，正值表示资金流入
- sentiment: 情绪因子 (-1 到 +1)，极端值需警惕
- trend: 趋势因子 (-1 到 +1)，正值表示上升趋势

## 调整原则
1. 保守型策略：宁可错过，不可做错，注重本金安全
2. 平衡型策略：风险与收益兼顾，适度灵活
3. 激进型策略：积极捕捉机会，可以承受较大波动

4. 动量强劲 + 成交量放大 → 可提高仓位、降低阈值
5. 波动率高 + 情绪极端 → 应提高现金保留
6. 趋势明确 → 可以更激进
7. 市场不明朗 → 应更保守

你需要输出调整后的参数和决策理由。
```

**User Prompt 示例:**
```
## 当前操盘手信息
- 风险偏好: conservative
- 投资风格: 我是稳健型投资者，注重长期价值投资...

## 基础策略参数
- max_positions: 2
- buy_signal_threshold: 0.60
- max_position_size: 0.40
- min_cash_reserve: 0.30

## 当前市场因子数据
- momentum: +0.65 (百分位: 78%)
- volatility: -0.15 (百分位: 35%)
- volume_ratio: +0.45 (百分位: 72%)
- sentiment: +0.30 (百分位: 65%)
- trend: +0.55 (百分位: 75%)

---

请根据以上信息，输出调整后的策略参数。

返回 JSON 格式：
{
  "max_positions": 数字(2-5),
  "buy_signal_threshold": 数字(0.3-0.7),
  "max_position_size": 数字(0.3-0.7),
  "min_cash_reserve": 数字(0.05-0.4),
  "reasoning": "简短说明为什么这样调整(50字以内)",
  "confidence": 0.0-1.0,
  "risk_warning": "风险提示(可选)"
}
```

### 11.3 AI 生成示例

**输入：**
```
风险偏好: conservative
基础策略: max_positions=2, threshold=0.60, position=0.40, cash=0.30

因子数据:
- momentum: +0.65 (百分位: 78%)
- volatility: -0.15 (百分位: 35%)
- volume_ratio: +0.45 (百分位: 72%)
- sentiment: +0.30 (百分位: 65%)
- trend: +0.55 (百分位: 75%)
```

**LLM 输出：**
```json
{
  "max_positions": 2,
  "buy_signal_threshold": 0.55,
  "max_position_size": 0.45,
  "min_cash_reserve": 0.28,
  "reasoning": "动量与趋势强劲，适度降低门槛、提高仓位，但仍保持保守底线",
  "confidence": 0.72,
  "risk_warning": "情绪偏乐观，需警惕回调风险"
}
```

### 11.4 服务层设计

```ruby
# app/services/ai_strategy_adjustment_service.rb
class AiStrategyAdjustmentService
  SYSTEM_PROMPT = <<~PROMPT
    你是一位专业的量化交易策略师。你的任务是根据当前市场因子数据，动态调整交易策略参数。
    # ... (如上所述)
  PROMPT

  def initialize(base_strategy, factor_values, asset_info = nil)
    @strategy = base_strategy
    @factors = factor_values
    @asset = asset_info
  end

  def call
    response = FactorLlmService.ask_json(user_prompt, instructions: SYSTEM_PROMPT)

    {
      adjusted_params: extract_params(response),
      reasoning: response["reasoning"],
      confidence: response["confidence"],
      risk_warning: response["risk_warning"]
    }
  rescue => e
    Rails.logger.error("AI strategy adjustment failed: #{e.message}")
    fallback_adjustment
  end

  private

  def user_prompt
    # 构建 user prompt，包含策略参数和因子数据
  end

  def extract_params(response)
    # 提取并验证参数范围
    {
      max_positions: clamp(response["max_positions"], 2, 5),
      buy_signal_threshold: clamp(response["buy_signal_threshold"], 0.3, 0.7),
      max_position_size: clamp(response["max_position_size"], 0.3, 0.7),
      min_cash_reserve: clamp(response["min_cash_reserve"], 0.05, 0.4)
    }
  end

  def fallback_adjustment
    # AI 失败时返回基础策略
    {
      adjusted_params: @strategy.slice(:max_positions, :buy_signal_threshold,
                                        :max_position_size, :min_cash_reserve),
      reasoning: "AI 服务暂时不可用，使用基础策略",
      confidence: 0.5,
      risk_warning: nil
    }
  end
end
```

---

## 十二、AI 交易 Agent（待实现）

> 更进一步的方案：让 AI 像真正的交易员一样分析市场、做出决策。

### 12.1 Agent 设计理念

不仅仅是微调参数，而是让 AI 综合分析所有信息，直接输出交易决策。

```
┌─────────────────────────────────────────────────────────────────────┐
│                     AI 交易 Agent 流程                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   输入                          AI Agent                  输出      │
│   ────                          ────────                  ────      │
│                                                                     │
│   操盘手档案  ──┐                                              ┌──→ action: buy/sell/hold
│                 │                                              │
│   基础策略    ──┼──→  ┌─────────────────────────────┐  ───┼──→ quantity: 35%
│                 │      │                             │      │
│   因子数据    ──┼──→  │  AI 交易员                   │  ───┼──→ reasoning: "..."
│                 │      │  - 分析市场状态              │      │
│   资产信息    ──┼──→  │  - 结合操盘手偏好            │  ───┼──→ confidence: 0.75
│                 │      │  - 做出交易决策              │      │
│   当前持仓    ──┘      │  - 给出清晰理由              │  ───┘──→ warnings: [...]
│                        │                             │
│                        └─────────────────────────────┘
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 12.2 Agent Prompt 设计

**System Prompt:**
```
你是 SmartTrader 平台的 AI 交易员。你负责分析市场数据并做出交易决策。

## 你的职责
1. 分析市场因子数据
2. 结合操盘手的策略偏好
3. 做出买入/卖出/持有决策
4. 给出清晰的决策理由

## 决策原则
- 始终考虑操盘手的风险偏好
- 多因子共振时更有信心
- 发现矛盾时，偏向保守
- 每个决策都要有明确理由
```

**User Prompt 示例:**
```
## 操盘手档案
- 名称: 巴菲特风格
- 风险偏好: conservative
- 投资风格: 我是稳健型投资者，注重长期价值投资...

## 当前策略
- 最大持仓: 2 个
- 买入阈值: 0.60
- 最大仓位: 40%
- 现金保留: 30%

## 目标资产
- 名称: Bitcoin
- 代码: BTC
- 类型: crypto
- 当前价格: $65,000

## 因子分析
- momentum: +0.65 (78%) - 上涨趋势强
- volatility: -0.15 (35%) - 波动温和
- volume_ratio: +0.45 (72%) - 资金流入明显
- sentiment: +0.30 (65%) - 偏乐观
- trend: +0.55 (75%) - 上升趋势

---

请分析以上信息，做出交易决策。

返回 JSON 格式：
{
  "action": "buy" | "sell" | "hold",
  "quantity_ratio": 0.0-1.0,
  "strategy": {
    "max_positions": 数字,
    "buy_signal_threshold": 数字,
    "max_position_size": 数字,
    "min_cash_reserve": 数字
  },
  "reasoning": "决策理由(100字以内)",
  "key_factors": ["关键因子1", "关键因子2"],
  "confidence": 0.0-1.0,
  "risk_level": "low" | "medium" | "high",
  "warnings": ["风险提示1", "风险提示2"]
}
```

### 12.3 Agent 输出示例

```json
{
  "action": "buy",
  "quantity_ratio": 0.35,
  "strategy": {
    "max_positions": 2,
    "buy_signal_threshold": 0.55,
    "max_position_size": 0.45,
    "min_cash_reserve": 0.28
  },
  "reasoning": "动量(+0.65)、成交量(+0.45)、趋势(+0.55)三因子共振向上，且波动率低，是较好的买入时机。但考虑到操盘手是保守型，建议仓位控制在35%。",
  "key_factors": ["动量因子", "成交量比率", "趋势因子"],
  "confidence": 0.75,
  "risk_level": "medium",
  "warnings": ["情绪因子偏乐观(+0.30)，需警惕市场过热"]
}
```

### 12.4 服务层设计

```ruby
# app/services/ai_trading_agent_service.rb
class AiTradingAgentService
  AGENT_PROMPT = <<~PROMPT
    你是 SmartTrader 平台的 AI 交易员。你负责分析市场数据并做出交易决策。
    # ... (如上所述)
  PROMPT

  def initialize(trader, asset, factor_values)
    @trader = trader
    @asset = asset
    @factors = factor_values
    @strategy = trader.default_strategy
  end

  def analyze_and_decide
    response = FactorLlmService.ask_json(decision_prompt, instructions: AGENT_PROMPT)

    TradingDecision.new(
      asset: @asset,
      action: response["action"],
      quantity_ratio: response["quantity_ratio"],
      adjusted_strategy: extract_strategy(response["strategy"]),
      reasoning: response["reasoning"],
      key_factors: response["key_factors"],
      confidence: response["confidence"],
      risk_level: response["risk_level"],
      warnings: response["warnings"]
    )
  end

  private

  def decision_prompt
    # 构建完整的决策 prompt
  end

  def format_factor_analysis
    # 格式化因子数据，包含解读
    @factors.map do |name, data|
      value = data[:normalized_value]
      interpretation = interpret_factor(name, value)
      "- #{name}: #{value.round(2)} - #{interpretation}"
    end.join("\n")
  end

  def interpret_factor(name, value)
    case name
    when "momentum"
      value > 0.3 ? "上涨趋势强" : (value < -0.3 ? "下跌趋势强" : "趋势不明")
    when "volatility"
      value > 0.3 ? "波动剧烈" : (value < -0.3 ? "波动温和" : "波动正常")
    when "volume_ratio"
      value > 0.3 ? "资金流入明显" : (value < -0.3 ? "资金流出明显" : "资金流向平衡")
    # ... 其他因子
    end
  end
end
```

### 12.5 混合模式：成本优化

为控制 API 成本，建议采用混合模式：

```ruby
# app/services/trading_orchestrator_service.rb
class TradingOrchestratorService
  def execute(trader)
    assets.each do |asset|
      factors = get_factors(asset)

      if significant_trade?(factors)
        # 重要交易：使用 AI Agent 深度分析
        decision = AiTradingAgentService.new(trader, asset, factors).analyze_and_decide
      else
        # 常规交易：使用 AI 策略微调（或纯数学）
        decision = quick_decision(trader, asset, factors)
      end

      execute_decision(decision)
    end
  end

  private

  def significant_trade?(factors)
    # 因子极端值 → 使用 AI Agent
    factors.any? { |_, v| v[:normalized_value].abs > 0.6 }
  end

  def quick_decision(trader, asset, factors)
    # 方案1: AI 策略微调
    # AiStrategyAdjustmentService.new(strategy, factors).call

    # 方案2: 纯数学（最低成本）
    # MathBasedDecisionService.new(strategy, factors).call
  end
end
```

### 12.6 方案对比

| 方案 | AI 参与度 | 灵活性 | 可解释性 | API 成本 | 适用场景 |
|------|----------|--------|---------|---------|---------|
| 纯数学微调 | 无 | 低 | 中 | 无 | 高频交易、成本敏感 |
| AI 策略微调 | 中 | 高 | 高 | 中 | 常规交易 |
| AI Agent | 高 | 最高 | 最高 | 高 | 重要交易、复杂决策 |
| 混合模式 | 可变 | 高 | 高 | 可控 | 推荐方案 |

---

## 十三、实施路线图

### Phase 1: AI 策略微调（优先级：高）

| 序号 | 任务 | 状态 |
|------|------|------|
| 1 | 设计 AiStrategyAdjustmentService | 待实现 |
| 2 | 编写 Prompt 模板 | 待实现 |
| 3 | 集成到交易流程 | 待实现 |
| 4 | 添加决策理由展示 | 待实现 |

### Phase 2: AI 交易 Agent（优先级：中）

| 序号 | 任务 | 状态 |
|------|------|------|
| 1 | 设计 AiTradingAgentService | 待实现 |
| 2 | 实现 TradingDecision 数据结构 | 待实现 |
| 3 | 实现混合模式调度器 | 待实现 |
| 4 | 添加 Agent 决策日志 | 待实现 |

### Phase 3: 优化与监控（优先级：低）

| 序号 | 任务 | 状态 |
|------|------|------|
| 1 | AI 决策质量评估 | 待实现 |
| 2 | Prompt 持续优化 | 待实现 |
| 3 | 成本监控与告警 | 待实现 |
| 4 | A/B 测试框架 | 待实现 |

---

## 十四、TODO List

### 14.1 MVP v1 功能清单

> 基于 `mvp_v1_plan.md` 的 7 个模块

| 模块 | 功能 | 状态 | 说明 |
|------|------|------|------|
| **模块1** | 操盘手管理 | ✅ 已完成 | Trader CRUD、风险等级、状态管理 |
| **模块2** | LLM 策略生成 | ✅ 已完成 | StrategyGeneratorService、4套策略/操盘手 |
| **模块3** | 资产数据采集 | ⬜ 未开始 | CollectAssetDataJob、yahoo-finance/ccxt 集成 |
| **模块4** | 交易因子计算 | ✅ 已完成 | FactorCalculatorService、6个因子 |
| **模块5** | 信号生成 | ✅ 已完成 | SignalGeneratorService、AI 信号生成 |
| **模块6** | 策略执行与资产配置 | ⬜ 未开始 | PortfolioAllocatorService、买入/卖出执行 |
| **模块7** | 盈亏展示 | ⬜ 未开始 | Portfolio 页面、盈亏曲线图 |

### 14.2 数据层完成情况

| 数据表 | 状态 | 说明 |
|--------|------|------|
| `users` | ✅ 已完成 | Google Sign-In 认证 |
| `traders` | ✅ 已完成 | 操盘手基础信息 |
| `trading_strategies` | ✅ 已完成 | 策略参数、4种市场环境 |
| `assets` | ✅ 已完成 | 资产基础信息 |
| `asset_snapshots` | ✅ 已完成 | 价格、成交量快照 |
| `factor_definitions` | ✅ 已完成 | 因子定义配置 |
| `factor_values` | ✅ 已完成 | 因子计算结果 |
| `trading_signals` | ⬜ 未开始 | 交易信号记录 |
| `portfolios` | ⬜ 未开始 | 投资组合 |
| `portfolio_positions` | ⬜ 未开始 | 持仓记录 |
| `allocation_decisions` | ⬜ 未开始 | 配置决策日志 |

### 14.3 服务层完成情况

| 服务 | 状态 | 说明 |
|------|------|------|
| `AiChatService` | ✅ 已完成 | LLM 调用封装 |
| `StrategyGeneratorService` | ✅ 已完成 | 策略生成 |
| `FactorCalculatorService` | ✅ 已完成 | 因子计算 |
| `FactorLlmService` | ✅ 已完成 | 因子 LLM 服务 |
| `SignalGeneratorService` | ✅ 已完成 | 信号生成 |
| `CollectAssetDataJob` | ⬜ 未开始 | 数据采集任务 |
| `CalculateFactorsJob` | ✅ 已完成 | 因子计算任务 |
| `GenerateSignalsJob` | ⬜ 未开始 | 信号生成任务 |
| `PortfolioAllocatorService` | ⬜ 未开始 | 资产配置服务 |
| `AiStrategyAdjustmentService` | ⬜ 未开始 | AI 策略微调（V2） |
| `AiTradingAgentService` | ⬜ 未开始 | AI 交易 Agent（V2） |

### 14.4 前端页面完成情况

| 页面 | 路径 | 状态 | 说明 |
|------|------|------|------|
| 操盘手列表 | `/traders` | ✅ 已完成 | |
| 操盘手详情 | `/traders/:id` | ✅ 已完成 | 含策略展示 |
| 操盘手创建 | `/traders/new` | ✅ 已完成 | 含描述输入 |
| 操盘手编辑 | `/traders/:id/edit` | ✅ 已完成 | |
| 因子列表 | `/admin/factor_definitions` | ✅ 已完成 | |
| 因子详情 | `/admin/factor_definitions/:id` | ✅ 已完成 | |
| 因子矩阵 | `/admin/factor_definitions/matrix` | ✅ 已完成 | 热力图展示 |
| 因子相关性 | `/admin/factor_definitions/correlations` | ✅ 已完成 | 相关性矩阵 |
| 信号列表 | `/signals` | ⬜ 未开始 | |
| 信号详情 | `/signals/:asset_id` | ⬜ 未开始 | |
| 投资组合 | `/traders/:id/portfolio` | ⬜ 未开始 | 持仓、盈亏 |
| 盈亏曲线 | `/traders/:id/performance` | ⬜ 未开始 | Chart.js 图表 |

### 14.5 进度统计

```
整体进度: ████████░░░░░░░░░░░░ 40%

已完成: 12 项
进行中: 0 项
未开始: 18 项

核心流程:
  操盘手创建 ──→ 策略配置 ──→ [数据采集] ──→ 因子计算 ──→ 信号生成 ──→ [策略执行] ──→ [盈亏展示]
     ✅            ✅           ⬜            ✅           ✅           ⬜           ⬜
```

### 14.6 下一步优先事项

按优先级排序：

| 优先级 | 任务 | 模块 | 预计工作量 |
|--------|------|------|-----------|
| 🔴 高 | CollectAssetDataJob | 模块3 | 1天 |
| 🔴 高 | TradingSignal 模型 + 迁移 | 模块5 | 0.5天 |
| 🔴 高 | GenerateSignalsJob | 模块5 | 0.5天 |
| 🟡 中 | Portfolio 模型 + 迁移 | 模块6 | 0.5天 |
| 🟡 中 | PortfolioAllocatorService | 模块6 | 1天 |
| 🟡 中 | 投资组合页面 | 模块7 | 1天 |
| 🟢 低 | 盈亏曲线图 | 模块7 | 0.5天 |
| 🟢 低 | AI 策略微调 | V2 | 1天 |
| 🟢 低 | AI 交易 Agent | V2 | 2天 |
