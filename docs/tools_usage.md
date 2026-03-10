# SmartTrader Tools 使用指南

## 概述

SmartTrader 使用 SwarmSDK 的 Tool 系统，让 AI Agent 可以动态获取需要的数据。

## 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                     AI Allocation Service                    │
│                                                              │
│  ┌─────────────┐                                            │
│  │   Context   │  trader_id: 123, capital: $100,000        │
│  └──────┬──────┘                                            │
│         │                                                    │
│         ▼                                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              SwarmSDK Agent (coordinator)            │   │
│  │                                                      │   │
│  │   1. Call TraderInfo(trader_id) → 策略配置           │   │
│  │   2. Call ListAssets() → 可用资产列表                │   │
│  │   3. Call GetSignalData(min_confidence: 0.7) → 信号  │   │
│  │   4. Call GetFactorData(symbols: [...]) → 因子       │   │
│  │   5. 生成配置建议 JSON                               │   │
│  │                                                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 可用 Tools

### 1. ListAssetsTool - 获取资产列表

```ruby
# 获取所有资产
ListAssetsTool.new.execute

# 只获取加密货币
ListAssetsTool.new.execute(asset_type: "crypto")

# 获取 Binance 交易所的资产
ListAssetsTool.new.execute(exchange: "crypto", limit: 50)
```

**参数：**
- `asset_type` (可选): crypto, stock, etf
- `exchange` (可选): 交易所名称
- `limit` (可选): 返回数量，默认 20，最大 100

### 2. GetAssetPriceTool - 获取资产价格

```ruby
# 获取 BTC 和 ETH 的价格
GetAssetPriceTool.new.execute(symbols: ["BTC", "ETH"])

```

**参数：**
- `symbols` (必需): 资产代码数组
- `exchange` (可选): 交易所名称

### 3. GetFactorDataTool - 获取因子数据

```ruby
# 获取所有资产的因子数据
GetFactorDataTool.new.execute

# 只获取 BTC 和 ETH 的因子
GetFactorDataTool.new.execute(symbols: ["BTC", "ETH"])

# 只获取技术因子
GetFactorDataTool.new.execute(category: "technical")

# 只获取高百分位因子（强势信号）
GetFactorDataTool.new.execute(min_percentile: 70)

# 组合筛选：BTC 的技术因子，且百分位 > 70
GetFactorDataTool.new.execute(
  symbols: ["BTC"],
  category: "technical",
  min_percentile: 70
)
```

**参数：**
- `symbols` (可选): 资产代码数组
- `category` (可选): technical, fundamental, sentiment, momentum, risk, volume
- `factor_codes` (可选): 具体因子代码数组
- `min_percentile` (可选): 最小百分位 0-100
- `max_percentile` (可选): 最大百分位 0-100

### 4. GetSignalDataTool - 获取交易信号

```ruby
# 获取所有最新信号
GetSignalDataTool.new.execute

# 只获取买入信号
GetSignalDataTool.new.execute(signal_type: "buy")

# 只获取高置信度信号
GetSignalDataTool.new.execute(min_confidence: 0.7)

# 组合筛选：高置信度的买入信号
GetSignalDataTool.new.execute(
  signal_type: "buy",
  min_confidence: 0.7,
  limit: 10
)
```

**参数：**
- `symbols` (可选): 资产代码数组
- `signal_type` (可选): buy, sell, hold
- `min_confidence` (可选): 最小置信度 0-1
- `limit` (可选): 返回数量，默认 20

### 5. TraderInfoTool - 获取操盘手信息 (Context-Aware)

```ruby
# 创建时需要传入 trader_id
tool = TraderInfoTool.new(trader_id: 123)
tool.execute

# 不包含策略详情
tool.execute(include_strategies: false)
```

**参数：**
- `include_strategies` (可选): 是否包含策略配置，默认 true

**Context Requirements:**
- `trader_id`: 操盘手 ID

## 在 SwarmSDK 中使用

### 方式 1: 直接注册 Tools

```ruby
# 在 initializer 或服务中注册
SwarmSDK.register_tool(ListAssetsTool)
SwarmSDK.register_tool(GetAssetPriceTool)
SwarmSDK.register_tool(GetFactorDataTool)
SwarmSDK.register_tool(GetSignalDataTool)
SwarmSDK.register_tool(TraderInfoTool)
```

### 方式 2: 在 Agent 中使用

```ruby
swarm = SwarmSDK.build do
  name "Asset Allocation Advisor"
  lead :coordinator

  agent :coordinator do
    model "gpt-5.2"
    description "投资组合协调器"

    system_prompt <<~PROMPT
      你是 SmartTrader 的投资组合协调器。
      使用可用的 Tools 获取数据并生成配置建议。

      1. 首先调用 TraderInfo 获取策略配置
      2. 使用 GetSignalData 获取高置信度信号
      3. 使用 GetFactorData 分析市场环境
      4. 生成配置建议
    PROMPT

    # 注册可用的 Tools
    tools :TraderInfo, :ListAssets, :GetAssetPrice, :GetFactorData, :GetSignalData
  end
end

# 执行时传入 trader_id 上下文
result = swarm.execute("test trader_id: 6")
```

## 设计优势

1. **按需获取数据**: AI Agent 自己决定需要哪些数据，避免传递大量无用数据
2. **灵活筛选**: 支持多种筛选条件，让 AI 专注于相关数据
3. **Context-Aware**: 某些 Tool 需要上下文（如 trader_id），在创建时注入
4. **可测试性**: 每个 Tool 可以独立测试
5. **可扩展性**: 添加新的 Tool 只需创建新的类并注册

## 与旧方案对比

| 特性 | 旧方案 (一次性传递) | 新方案 (Tool 调用) |
|------|-------------------|-------------------|
| 数据获取 | 全部数据打包传递 | AI 按需调用 Tools |
| 上下文大小 | 很大，包含所有数据 | 很小，只有 trader_id |
| 灵活性 | 固定数据格式 | AI 可以自由筛选 |
| Token 消耗 | 高（一次性传所有数据） | 按需消耗 |
| 可维护性 | 数据收集逻辑分散 | 集中在 Tool 类中 |
