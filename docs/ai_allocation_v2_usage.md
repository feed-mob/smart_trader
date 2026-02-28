# AiAllocationServiceV2 使用指南

## 概述

`AiAllocationServiceV2` 是一个独立的资产分析服务，不依赖 `Trader` 和 `TradingStrategy`。它专注于：
- 分析用户输入的资产
- 计算多维度因子
- 生成交易信号
- 提供基于 AI 的策略建议

## 快速开始

### 1. 基本使用

```ruby
# 分析指定的资产列表
service = AiAllocationServiceV2.new(
  symbols: ["BTC", "ETH", "SOL"],
  capital: 100_000,                    # 可选：可用资金，默认 100000
  risk_preference: "balanced"          # 可选：conservative/balanced/aggressive
)
result = service.run_full_pipeline

# 查看日志
puts result[:logs].join("\n")

# 查看结果
puts "MCP 数据: #{result[:mcp_data].length} 条"
puts "资产数量: #{result[:assets].length} 个"
puts "信号统计: #{result[:signals]}"
puts "AI 建议: #{result[:recommendation]}"
```

### 2. 不同风险偏好

```ruby
# 保守型
conservative_service = AiAllocationServiceV2.new(
  symbols: ["BTC"],
  risk_preference: "conservative"  # 单资产最大15%，现金保留30%+
)

# 平衡型（默认）
balanced_service = AiAllocationServiceV2.new(
  symbols: ["BTC", "ETH"],
  risk_preference: "balanced"       # 单资产最大25%，现金保留20%+
)

# 激进型
aggressive_service = AiAllocationServiceV2.new(
  symbols: ["BTC", "ETH", "SOL", "DOGE"],
  risk_preference: "aggressive"     # 单资产最大40%，现金保留10%+
)
```

### 3. 单独测试某个 Phase

```ruby
service = AiAllocationServiceV2.new(symbols: ["BTC"])

# 只测试 Phase 1: MCP 数据获取
mcp_data = service.send(:execute_phase_1_mcp_data_fetch)

# 只测试 Phase 2: 保存到资产表
assets = service.send(:execute_phase_2_save_to_assets, mcp_data)

# 只测试 Phase 3: 计算因子
service.send(:execute_phase_3_calculate_factors, assets)

# 只测试 Phase 4: 生成信号
signals = service.send(:execute_phase_4_generate_signals, assets)

# 只测试 Phase 5: AI 建议
recommendation = service.send(:execute_phase_5_ai_recommendation, assets, signals)
```

## 初始化参数

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `symbols` | Array<String> | 否 | `[]` | 资产代码列表，如 `["BTC", "ETH"]` |
| `capital` | Float | 否 | `100000` | 可用资金（美元） |
| `risk_preference` | String | 否 | `"balanced"` | 风险偏好：conservative/balanced/aggressive |
| `exchange` | String | 否 | `"KUCOIN"` | 交易所 |
| `timeframe` | String | 否 | `"15m"` | 时间框架 |

## 返回结果结构

```ruby
{
  logs: [...],           # 详细日志数组
  mcp_data: [...],       # MCP 获取的原始数据
  assets: [...],         # 分析的资产对象列表
  signals: {             # 信号统计
    buy: 3,
    sell: 2,
    hold: 5
  },
  recommendation: {      # AI 建议结果
    market_analysis: "市场环境分析...",
    market_condition: "normal",     # normal/volatile/crash/bubble
    risk_level: "medium",           # low/medium/high
    suggested_actions: [
      {
        symbol: "BTC",
        action: "buy",               # buy/sell/hold
        confidence: 0.8,
        suggested_allocation_percent: 30,
        reason: "建议理由"
      }
    ],
    strategy_recommendations: {     # 策略参数建议
      max_positions: 5,
      buy_signal_threshold: 0.6,
      max_position_size: 0.25,
      min_cash_reserve: 0.2,
      reasoning: "策略参数建议理由"
    },
    overall_summary: "整体建议摘要",
    risk_warnings: ["风险提示1", "风险提示2"],
    generated_at: Time.current
  },
  analyzed_at: Time.current
}
```

## 分析流程

1. **Phase 1: MCP 数据获取** - 从交易所获取实时行情数据
2. **Phase 2: 保存到资产表** - 将数据持久化到 Asset 和 AssetSnapshot
3. **Phase 3: 计算因子** - 计算动量、波动率、RSI 等技术因子
4. **Phase 4: 生成信号** - 基于因子生成 buy/sell/hold 信号
5. **Phase 5: AI 建议** - 调用 AI 生成策略和配置建议

## 故障排除

### MCP 连接失败
- 检查 `uv` 是否安装: `which uv`
- 检查网络连接
- 查看错误日志，服务会自动使用模拟数据作为备用

### 数据库错误
- 检查表是否存在: `rails db:migrate:status`
- 检查字段是否正确

### 信号生成失败
- 确保有 Asset 和 AssetSnapshot 数据
- 检查 FactorDefinition 是否存在

## 与 V1 的区别

| 特性 | V1 | V2 |
|------|----|----|
| 依赖 Trader | 是 | 否 |
| 依赖 TradingStrategy | 是 | 否 |
| 输入参数 | `trader` 对象 | `symbols` 数组 + 配置选项 |
| 策略来源 | 预设策略 | AI 动态生成建议 |
| 适用场景 | 操盘手自动交易 | 独立资产分析 |