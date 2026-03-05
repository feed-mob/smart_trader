# frozen_string_literal: true

# AI配置建议服务 - 使用 SwarmSDK 多 Agent 系统生成资产配置建议
class AiAllocationService
  def initialize(trader)
    @trader = trader
    @strategies = trader.trading_strategies.order(:market_condition)
    @capital = trader.current_capital_value
  end

  # 生成完整的配置预览
  def generate_preview
    assets_data = collect_asset_data
    recommendation = call_swarm_for_recommendation(assets_data)

    {
      trader: trader_info,
      strategies: strategies_info,
      signals: extract_signals(assets_data),
      factors: extract_factors(assets_data),
      assets: assets_data,
      recommendation: recommendation
    }
  end

  # 只生成 AI 配置建议（用于异步加载）
  def generate_recommendation
    assets_data = collect_asset_data
    call_swarm_for_recommendation(assets_data)
  end

  # 提取信号摘要
  def extract_signals(assets_data)
    assets_data.filter_map do |data|
      next if data[:signal].blank?

      {
        symbol: data[:symbol],
        name: data[:name],
        signal_type: data[:signal],
        confidence: data[:confidence],
        reasoning: data[:reasoning]
      }
    end
  end

  # 提取因子摘要
  def extract_factors(assets_data)
    assets_data.map do |data|
      {
        symbol: data[:symbol],
        name: data[:name],
        factors: data[:factors]
      }
    end
  end

  private

  # 操盘手基本信息
  def trader_info
    {
      id: @trader.id,
      name: @trader.name,
      risk_level: @trader.risk_level,
      display_risk_level: @trader.display_risk_level,
      initial_capital: @trader.initial_capital,
      current_capital: @capital
    }
  end

  # 收集所有资产的数据（价格、信号、因子）
  def collect_asset_data
    Asset.all.map do |asset|
      snapshot = asset.latest_snapshot
      factor_values = collect_factor_values(asset)
      signal = collect_latest_signal(asset)

      {
        symbol: asset.symbol,
        name: asset.name,
        asset_type: asset.asset_type,
        price: snapshot&.price,
        signal: signal&.signal_type,
        confidence: signal&.confidence,
        reasoning: signal&.reasoning,
        factors: factor_values
      }
    end
  end

  # 收集资产的因子值
  def collect_factor_values(asset)
    factor_values = FactorValue.where(asset: asset).latest
      .joins(:factor_definition)
      .pluck(
        "factor_definitions.code",
        "factor_definitions.name",
        "factor_definitions.category",
        "factor_values.normalized_value",
        "factor_values.percentile"
      )

    factor_values.map do |code, name, category, normalized_value, percentile|
      {
        code: code,
        name: name,
        category: category,
        value: normalized_value&.round(2),
        percentile: percentile&.round(1)
      }
    end
  end

  # 收集资产的最新信号
  def collect_latest_signal(asset)
    TradingSignal.where(asset: asset).order(generated_at: :desc).first
  end

  # 策略信息
  def strategies_info
    @strategies.map do |strategy|
      {
        market_condition: strategy.market_condition,
        display_market_condition: strategy.display_market_condition,
        risk_level: strategy.risk_level,
        max_positions: strategy.max_positions,
        buy_signal_threshold: strategy.buy_signal_threshold,
        max_position_size: strategy.max_position_size,
        min_cash_reserve: strategy.min_cash_reserve,
        name: strategy.name,
        description: strategy.description
      }
    end
  end

  # 使用 SwarmSDK 多 Agent 系统生成配置建议
  def call_swarm_for_recommendation(assets_data)
    context = build_swarm_context(assets_data)
    swarm = build_allocation_swarm
    result = swarm.execute(context)
    Rails.logger.info "[AiAllocationService] Swarm result: #{result.inspect}"
    parse_swarm_result(result)
  end

  # 构建 Swarm 上下文
  def build_swarm_context(assets_data)
    <<~CONTEXT
      ## 操盘手信息
      - 名称: #{@trader.name}
      - 风险偏好: #{@trader.display_risk_level}
      - 可用资金: $#{number_with_delimiter(@capital.round(0))}

      ## 策略配置
      #{format_strategies_for_context}

      ## 资产数据
      #{format_assets_for_context(assets_data)}

      请分析以上数据，生成资产配置建议。
    CONTEXT
  end

  # 构建 Allocation Swarm - 简化为 2 个 Agent
  def build_allocation_swarm
    SwarmSDK.build do
      name "Asset Allocation Advisor"
      lead :coordinator

      # 协调器 Agent - 负责分析市场、因子、信号并决策
      agent :coordinator do
        model "claude-sonnet-4-6"
        description "投资组合协调器，分析市场、因子、信号并选择策略"

        system_prompt <<~PROMPT
          你是 SmartTrader 的投资组合协调器。你的职责是：
          1. 分析因子数据判断市场环境（normal/volatile/crash/bubble）
          2. 分析每个资产的交易信号和置信度
          3. 选择最合适的交易策略
          4. 委派配置计算任务给 allocation_planner

          市场环境判断标准：
          - normal: 因子值正常，波动适中
          - volatile: 波动率因子偏高（>70%百分位）
          - crash: 多数因子为负，市场恐慌
          - bubble: 动量过热，情绪因子极端

          信号评估：
          - 高置信度信号（>0.7）值得跟随
          - 低置信度信号应谨慎对待
        PROMPT

        delegates_to :allocation_planner
      end

      # 配置规划 Agent - 负责计算具体配置方案
      agent :allocation_planner do
        model "claude-sonnet-4-6"
        description "根据策略和信号计算资产配置方案"

        system_prompt <<~PROMPT
          你是资产配置规划专家。你的职责是：
          1. 根据策略参数约束计算配置方案
          2. 计算每个资产的配置比例和金额
          3. 确保满足现金保留要求
          4. 返回 JSON 格式的配置建议

          配置约束：
          - 遵循 max_positions 限制
          - 单资产不超过 max_position_size
          - 保留至少 min_cash_reserve 的现金
          - 只对信号置信度超过 buy_signal_threshold 的资产买入

          ## 输出格式要求

          你的回复必须只包含一个 JSON 对象：

          {
            "market_analysis": "市场环境分析（1-2句话）",
            "selected_strategy": "normal 或 volatile 或 crash 或 bubble",
            "strategy_selection_reason": "选择该策略的理由",
            "summary": "配置建议摘要（1-2句话）",
            "allocations": [
              {
                "symbol": "资产代码如BTC",
                "action": "buy 或 sell 或 hold",
                "allocation_percent": 30,
                "amount_usd": 30000,
                "shares": 0.5,
                "reason": "配置理由"
              }
            ],
            "cash_reserve": {
              "percent": 20,
              "amount_usd": 20000
            },
            "detailed_reasoning": "详细解释（3-5句话）"
          }

          注意：
          - 如果没有合适的买入机会，allocations 为空数组 []
          - allocation_percent + cash_reserve.percent = 100
        PROMPT
      end
    end
  end

  # 解析 Swarm 结果
  def parse_swarm_result(result)
    parse_json_response(result.content)
  end

  # 格式化策略信息用于上下文
  def format_strategies_for_context
    @strategies.map do |strategy|
      <<~STRATEGY
        ### #{strategy.display_market_condition} (#{strategy.market_condition})
        - 策略名称: #{strategy.name}
        - 最大持仓数: #{strategy.max_positions}
        - 买入信号阈值: #{(strategy.buy_signal_threshold * 100).to_i}%
        - 单资产最大仓位: #{(strategy.max_position_size * 100).to_i}%
        - 最小现金保留: #{(strategy.min_cash_reserve * 100).to_i}%
        - 描述: #{strategy.description}
      STRATEGY
    end.join("\n")
  end

  # 格式化资产信息用于上下文
  def format_assets_for_context(assets_data)
    assets_data.map do |data|
      signal_info = if data[:signal]
        "信号: #{data[:signal].upcase} (置信度: #{(data[:confidence] * 100).round(1) if data[:confidence]}%)\n理由: #{data[:reasoning]}"
      else
        "信号: 无"
      end

      factors_info = if data[:factors].any?
        data[:factors].map { |f| "  - #{f[:name]}: #{f[:value]} (百分位: #{f[:percentile]}%)" }.join("\n")
      else
        "  暂无因子数据"
      end

      <<~ASSET
        ### #{data[:name]} (#{data[:symbol]})
        - 类型: #{data[:asset_type]}
        - 当前价格: $#{data[:price]&.round(2) || 'N/A'}
        - #{signal_info}
        - 因子数据:
        #{factors_info}
      ASSET
    end.join("\n")
  end

  # 解析响应 - 使用 RubyLLM 解析 Markdown
  def parse_json_response(response)
    return nil if response.blank?

    Rails.logger.info "[AiAllocationService] Raw response length: #{response.length}"
    parse_markdown_response(response)
  end

  # 解析 Markdown 格式的响应 - 使用 AiChatService
  def parse_markdown_response(markdown_content)
    Rails.logger.info "[AiAllocationService] Using AiChatService to parse Markdown"

    prompt = <<~PROMPT
      请从以下资产配置建议的 Markdown 文本中提取结构化信息，返回纯 JSON 格式（不要包含 ```json 标记）。

      ## 输入文本
      #{markdown_content}

      ## 可用资金
      #{@capital}

      ## 输出要求
      返回纯 JSON 对象，不要包含 markdown 代码块标记，不要包含任何 error 相关字段。JSON 结构如下：

      {
        "market_analysis": "市场环境分析（1-2句话）",
        "selected_strategy": "normal 或 volatile 或 crash 或 bubble",
        "strategy_selection_reason": "选择该策略的理由",
        "summary": "配置建议摘要（1-2句话）",
        "allocations": [
          {
            "symbol": "资产代码如BTC",
            "action": "buy 或 sell 或 hold",
            "allocation_percent": 30,
            "amount_usd": 30000,
            "shares": 0.5,
            "reason": "配置理由"
          }
        ],
        "cash_reserve": {
          "percent": 20,
          "amount_usd": 20000
        },
        "detailed_reasoning": "详细解释（3-5句话）"
      }

      重要提示：
      - 只提取有效的配置建议数据，忽略输入文本中的任何 error 或错误信息
      - 如果没有配置任何资产（全部现金），allocations 为空数组 []
      - allocation_percent + cash_reserve.percent 必须等于 100
      - 如果文本中提到"100%现金"或"全部现金观望"，则 allocations 为空，cash_reserve.percent 为 100
      - amount_usd 需要根据可用资金和百分比计算
    PROMPT

    ai_service = AiChatService.new
    content = ai_service.ask(prompt)
    Rails.logger.info "[AiAllocationService] AiChatService response length: #{content.length}"
    Rails.logger.info "[AiAllocationService] AiChatService response content: #{content}"

    # 提取并解析 JSON
    json_string = extract_json_from_llm_response(content)
    result = JSON.parse(json_string)
    Rails.logger.info "[AiAllocationService] Successfully parsed LLM JSON with keys: #{result.keys.join(', ')}"

    symbolize_keys(result)
  end

  # 从 LLM 响应中提取 JSON 字符串
  def extract_json_from_llm_response(content)
    # 尝试从 markdown 代码块中提取
    if content =~ /```(?:json)?\s*(\{.*\})\s*```/m
      return Regexp.last_match(1)
    end

    # 找到 JSON 对象
    start_index = content.index("{")
    end_index = content.rindex("}")
    if start_index && end_index && end_index > start_index
      return content[start_index..end_index]
    end

    content.strip
  end


  # 将哈希的键名符号化（递归）
  def symbolize_keys(obj)
    case obj
    when Hash
      obj.transform_keys(&:to_sym).transform_values { |v| symbolize_keys(v) }
    when Array
      obj.map { |v| symbolize_keys(v) }
    else
      obj
    end
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\\1,").reverse
  end
end
