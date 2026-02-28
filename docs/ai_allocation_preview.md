# AI 配置预览系统 (AI Allocation Preview System)

## 概述

从**操盘手详情页**进入配置预览页面，AI 根据信号、因子、操盘手的4个策略动态生成持仓买卖建议。

## 流程

```
操盘手详情页 (/admin/traders/:id)
    ↓ 点击"AI配置建议"按钮
配置预览页 (/admin/traders/:id/allocation_preview)
    ↓ 自动显示
AI 分析结果
```

## AI 分析内容

1. **所有资产的最新信号** - TradingSignal
2. **操盘手的4个策略** - normal/volatile/crash/bubble
3. **所有资产的因子数据** - FactorValue

## 输出内容

- 市场环境判断
- 选择的策略（4选1）
- 每个资产的买卖建议
- 配置比例、金额、数量
- 详细配置理由

---

## 实现计划

### Step 1: AiAllocationService (AI配置建议服务)

**文件**: `app/services/ai_allocation_service.rb`

```ruby
class AiAllocationService
  def initialize(trader)
    @trader = trader
    @strategies = trader.trading_strategies.includes(:trader)
    @capital = trader.initial_capital
  end

  def generate_preview
    assets_data = collect_asset_data

    {
      trader: {
        id: @trader.id,
        name: @trader.name,
        risk_level: @trader.risk_level,
        initial_capital: @capital
      },
      strategies: strategies_info,           # 4个策略
      signals: extract_signals(assets_data), # 所有信号
      factors: extract_factors(assets_data), # 所有因子
      assets: assets_data,                   # 资产完整数据
      recommendation: call_ai_for_recommendation(assets_data)  # AI建议
    }
  end

  private

  def collect_asset_data
    Asset.all.map do |asset|
      factor_values = FactorValue.latest.by_asset(asset.id)
        .joins(:factor_definition)
        .pluck('factor_definitions.code', 'factor_definitions.name',
               'factor_values.normalized_value', 'factor_values.percentile')

      signal = TradingSignal.latest.by_asset(asset.id).first

      {
        symbol: asset.symbol,
        name: asset.name,
        price: asset.current_price,
        signal: signal&.signal_type,
        confidence: signal&.confidence,
        reasoning: signal&.reasoning,
        factors: factor_values.map { |code, name, value, percentile|
          { code: code, name: name, value: value, percentile: percentile }
        }
      }
    end
  end

  def extract_signals(assets_data)
    assets_data.map do |data|
      {
        symbol: data[:symbol],
        name: data[:name],
        signal_type: data[:signal],
        confidence: data[:confidence],
        reasoning: data[:reasoning]
      }
    end
  end

  def extract_factors(assets_data)
    assets_data.map do |data|
      {
        symbol: data[:symbol],
        name: data[:name],
        factors: data[:factors]
      }
    end
  end

  def strategies_info
    @strategies.map do |s|
      {
        market_condition: s.market_condition,
        risk_level: s.risk_level,
        max_positions: s.max_positions,
        buy_signal_threshold: s.buy_signal_threshold,
        max_position_size: s.max_position_size,
        min_cash_reserve: s.min_cash_reserve
      }
    end
  end

  def build_prompt(assets_data)
    <<~PROMPT
      你是一位专业的投资组合经理。请根据以下信息做出资产配置建议。

      ## 操盘手信息
      - 名称: #{@trader.name}
      - 风险偏好: #{@trader.risk_level}
      - 可用资金: $#{@capital}

      ## 操盘手的4个策略（针对不同市场环境）
      #{format_strategies_for_prompt}

      ## 资产数据（信号+因子）
      #{format_assets_for_prompt(assets_data)}

      ## 任务
      请综合分析：
      1. 当前市场环境判断（基于因子数据）
      2. 选择合适的策略参数
      3. 根据信号和因子决定买卖操作
      4. 计算具体配置比例和金额
      5. 详细解释配置理由

      ## 输出要求
      返回 JSON 格式：
      ```json
      {
        "market_analysis": "当前市场环境分析（1-2句话）",
        "selected_strategy": "normal|volatile|crash|bubble",
        "strategy_selection_reason": "为什么选择这个策略",
        "summary": "配置建议摘要（1-2句话）",
        "allocations": [
          {
            "symbol": "BTC",
            "action": "buy|sell|hold",
            "allocation_percent": 30,
            "amount_usd": 30000,
            "shares": 0.5,
            "reason": "具体理由（引用具体的因子值和信号）"
          }
        ],
        "cash_reserve": {
          "percent": 20,
          "amount_usd": 20000
        },
        "detailed_reasoning": "详细解释整体配置逻辑（3-5句话，引用具体数据）"
      }
      ```

      约束条件：
      1. 遵循所选策略的参数限制
      2. 综合考虑多个因子的信号
      3. 在理由中引用具体的因子值和信号置信度
    PROMPT
  end

  def format_strategies_for_prompt
    @strategies.map do |s|
      <<~STRATEGY
        ### #{s.market_condition.upcase} 策略
        - 风险等级: #{s.risk_level}
        - 最大持仓数: #{s.max_positions}
        - 买入信号阈值: #{s.buy_signal_threshold}
        - 单资产最大仓位: #{(s.max_position_size * 100).to_i}%
        - 最小现金保留: #{(s.min_cash_reserve * 100).to_i}%
      STRATEGY
    end.join("\n")
  end

  def format_assets_for_prompt(assets_data)
    assets_data.map do |data|
      factors_str = data[:factors].map do |f|
        "  - #{f[:name]}: #{f[:value].round(2)} (百分位: #{f[:percentile].to_i}%)"
      end.join("\n")

      <<~ASSET
        ### #{data[:symbol]} (#{data[:name]})
        - 当前价格: $#{data[:price]}
        - 信号: #{data[:signal]&.upcase || 'N/A'}
        - 置信度: #{data[:confidence]&.round(2) || 'N/A'}
        - 信号理由: #{data[:reasoning] || 'N/A'}
        - 因子数据:
        #{factors_str}
      ASSET
    end.join("\n")
  end

  def call_ai_for_recommendation(assets_data)
    prompt = build_prompt(assets_data)
    response = AiChatService.new.ask(prompt)
    parse_json_response(response.body)
  end
end
```

### Step 2: Controller

**文件**: `app/controllers/admin/allocation_previews_controller.rb`

```ruby
class Admin::AllocationPreviewsController < ApplicationController
  before_action :set_trader

  def show
    @preview = AiAllocationService.new(@trader).generate_preview
  end

  private

  def set_trader
    @trader = Trader.find(params[:trader_id])
  end
end
```

### Step 3: Views

**文件**: `app/views/admin/allocation_previews/show.html.erb`

**页面布局：**

```
┌─────────────────────────────────────────────────────────────┐
│ 操盘手信息                                                    │
│ - 名称、风险偏好、可用资金                                      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 📊 使用的信号 (Signals)                                       │
│ ┌─────────┬────────┬──────────┬──────────────────────────┐  │
│ │ 资产    │ 信号   │ 置信度   │ 理由                     │  │
│ ├─────────┼────────┼──────────┼──────────────────────────┤  │
│ │ BTC     │ BUY    │ 0.85     │ 动量强劲，趋势向上...     │  │
│ │ ETH     │ HOLD   │ 0.60     │ 信号不明确...            │  │
│ │ AAPL    │ SELL   │ 0.72     │ 技术指标转弱...          │  │
│ └─────────┴────────┴──────────┴──────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 📈 使用的因子 (Factors)                                       │
│ ┌─────────┬──────────┬──────────┬──────────┬─────────────┐  │
│ │ 资产    │ 动量因子  │ 波动因子  │ 情绪因子  │ 成交量因子   │  │
│ ├─────────┼──────────┼──────────┼──────────┼─────────────┤  │
│ │ BTC     │ +0.75    │ +0.32    │ +0.68    │ +0.45       │  │
│ │ ETH     │ +0.42    │ +0.55    │ +0.30    │ +0.28       │  │
│ │ AAPL    │ -0.35    │ +0.20    │ -0.42    │ -0.15       │  │
│ └─────────┴──────────┴──────────┴──────────┴─────────────┘  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ ⚙️ 使用的策略 (Strategies)                                    │
│ ┌──────────────┬────────┬──────────┬──────────┬──────────┐  │
│ │ 市场环境     │ 风险   │ 最大持仓  │ 买入阈值  │ 选择状态   │  │
│ ├──────────────┼────────┼──────────┼──────────┼──────────┤  │
│ │ Normal       │ 平衡   │ 3        │ 0.5      │ ✓ 已选择   │  │
│ │ Volatile     │ 保守   │ 2        │ 0.6      │           │  │
│ │ Crash        │ 保守   │ 1        │ 0.7      │           │  │
│ │ Bubble       │ 激进   │ 4        │ 0.4      │           │  │
│ └──────────────┴────────┴──────────┴──────────┴──────────┘  │
│ AI判断: "当前市场波动适中，选择Normal策略"                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 🤖 AI 配置建议                                               │
│                                                              │
│ 市场分析: "当前市场处于正常波动状态，动量因子整体积极..."        │
│ 配置摘要: "建议买入BTC和ETH，保留20%现金应对波动..."            │
│                                                              │
│ ┌─────────┬────────┬────────┬──────────┬─────────┬─────────┐│
│ │ 资产    │ 操作   │ 比例   │ 金额(USD)│ 数量    │ 理由    ││
│ ├─────────┼────────┼────────┼──────────┼─────────┼─────────┤│
│ │ BTC     │ BUY    │ 40%    │ $40,000  │ 0.52    │ 动量+信号││
│ │ ETH     │ BUY    │ 25%    │ $25,000  │ 8.33    │ 信号积极 ││
│ │ AAPL    │ HOLD   │ 0%     │ $0       │ 0       │ 等待机会 ││
│ │ GLD     │ BUY    │ 15%    │ $15,000  │ 75      │ 对冲风险 ││
│ └─────────┴────────┴────────┴──────────┴─────────┴─────────┘│
│                                                              │
│ 💰 现金保留: $20,000 (20%)                                   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 📝 配置理由详解                                               │
│                                                              │
│ AI 详细解释为什么这样配置：                                    │
│                                                              │
│ "1. 选择BTC作为主要持仓(40%)，因为其动量因子(+0.75)            │
│    和买入信号(0.85置信度)都非常强劲...                         │
│                                                              │
│  2. ETH配置25%，虽然动量较弱但整体信号积极...                   │
│                                                              │
│  3. AAPL暂时观望，技术因子转负...                              │
│                                                              │
│  4. 保留20%现金，符合Normal策略的min_cash_reserve要求..."       │
└─────────────────────────────────────────────────────────────┘

[执行配置] 按钮（后续功能）
```

### Step 4: 添加入口按钮

**修改文件**: `app/views/admin/traders/show.html.erb`

```erb
<%= link_to "AI配置建议", trader_allocation_preview_path(@trader), class: "btn btn-primary" %>
```

### Step 5: Routes

```ruby
# config/routes.rb
namespace :admin do
  resources :traders do
    resource :allocation_preview, only: [:show]
  end
end
```

---

## 需要创建/修改的文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `app/services/ai_allocation_service.rb` | 创建 | **核心服务** - 收集数据，调用AI |
| `app/controllers/admin/allocation_previews_controller.rb` | 创建 | 控制器 |
| `app/views/admin/allocation_previews/show.html.erb` | 创建 | 配置预览页面 |
| `app/views/admin/traders/show.html.erb` | 修改 | 添加"AI配置建议"按钮 |
| `config/routes.rb` | 修改 | 添加嵌套路由 |

**不需要新建数据库表**

---

## 验证步骤

1. 访问操盘手详情页: `/admin/traders/:id`
2. 点击"AI配置建议"按钮
3. 等待 AI 生成配置建议
4. 检查页面显示：
   - 使用的信号列表
   - 使用的因子表格
   - 使用的策略（标注选择状态）
   - AI 配置建议明细
   - 配置理由详解

---

## 参考文件

- `app/models/trading_strategy.rb` - 策略模型
- `app/models/trader.rb` - 操盘手模型
- `app/services/factor_llm_service.rb` - LLM调用模式
- `app/services/ai_chat_service.rb` - AI服务
- `app/views/admin/traders/show.html.erb` - 操盘手详情页
