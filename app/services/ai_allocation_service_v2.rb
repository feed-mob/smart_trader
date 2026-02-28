# frozen_string_literal: true

# AI 资产分析服务 V2 - 独立的资产分析引擎
#
# 核心功能：
# 1. 使用 MCP 获取资产数据
# 2. 计算多维度因子（动量、波动率、技术指标等）
# 3. 生成交易信号
# 4. 提供 AI 驱动的策略建议
#
# 使用方式：
#   service = AiAllocationServiceV2.new(symbols: ["BTC", "ETH"])
#   result = service.run_full_pipeline
#
class AiAllocationServiceV2
  # 初始化资产分析服务
  #
  # @param symbols [Array<String>] 资产代码列表，如 ["BTC", "ETH", "SOL"]
  # @param options [Hash] 可选配置
  # @option options [String] :exchange 交易所，默认 "KUCOIN"
  # @option options [String] :timeframe 时间框架，默认 "15m"
  # @option options [Float] :capital 可用资金（用于计算建议仓位），默认 100000
  # @option options [String] :risk_preference 风险偏好 "conservative"/"balanced"/"aggressive"，默认 "balanced"
  #
  def initialize(symbols: [], **options)
    @symbols = normalize_symbols(symbols)
    @options = default_options.merge(options)
    @logs = []
  end

  # 默认配置
  def default_options
    {
      exchange: "KUCOIN",
      timeframe: "15m",
      capital: 100_000,
      risk_preference: "balanced"
    }
  end

  # 执行完整的分析流程
  #
  # @return [Hash] 包含 mcp_data, assets, signals, recommendation, logs
  #
  def run_full_pipeline
    log "=" * 80
    log "[AiAllocationServiceV2] 开始执行资产分析流程"
    log "[资产列表] #{@symbols.join(', ')}"
    log "[可用资金] $#{number_with_delimiter(@options[:capital].round(0))}"
    log "[风险偏好] #{@options[:risk_preference]}"
    log "=" * 80

    # Phase 1: MCP 数据获取
    mcp_data = execute_phase_1_mcp_data_fetch

    # Phase 2: 保存到资产表
    assets = execute_phase_2_save_to_assets(mcp_data)

    # Phase 3: 计算因子
    execute_phase_3_calculate_factors(assets)

    # Phase 4: 生成信号
    signals = execute_phase_4_generate_signals(assets)

    # Phase 5: AI 策略建议
    recommendation = execute_phase_5_ai_recommendation(assets, signals)

    log "=" * 80
    log "[AiAllocationServiceV2] 资产分析流程执行完成"
    log "=" * 80

    {
      logs: @logs,
      mcp_data: mcp_data,
      assets: assets,
      signals: signals,
      recommendation: recommendation,
      analyzed_at: Time.current
    }
  end

  private

  # 规范化资产代码
  def normalize_symbols(symbols)
    symbols.map do |symbol|
      symbol.to_s.upcase.gsub(/[^A-Z]/, "")
    end.reject(&:empty?).uniq
  end

  # ============================================================================
  # Phase 1: MCP 数据获取
  # ============================================================================
  def execute_phase_1_mcp_data_fetch
    log_phase_start("Phase 1: MCP 数据获取")

    # 如果用户提供了具体的资产列表，针对性获取
    if @symbols.any?
      mcp_data = fetch_specific_assets_data
    else
      # 否则获取热门资产
      mcp_data = fetch_top_gainers_data
    end

    mcp_data.each do |asset|
      log "  - #{asset[:symbol]}: #{asset[:change_percent]}%"
    end

    log_phase_end("Phase 1", "成功获取 #{mcp_data.length} 条资产数据")
    mcp_data
  end

  # 获取指定资产的数据
  def fetch_specific_assets_data
    log "[MCP] 获取指定资产数据: #{@symbols.join(', ')}"

    # 构建 Swarm 来获取 MCP 数据
    swarm = build_mcp_swarm
    prompt = build_fetch_prompt_for_symbols
    result = swarm.execute(prompt)

    parse_mcp_response(result&.content || result.to_s)
  end

  # 获取涨幅最大的资产
  def fetch_top_gainers_data
    log "[MCP] 获取热门涨幅资产..."

    swarm = build_mcp_swarm
    result = swarm.execute("获取 KuCoin 上过去15分钟涨幅最大的10个加密货币")

    parse_mcp_response(result&.content || result.to_s)
  end

  # 构建获取指定资产的 prompt
  def build_fetch_prompt_for_symbols
    symbols_with_usdt = @symbols.map { |s| s.end_with?("USDT") ? s : "#{s}USDT" }
    "获取以下加密货币在 KuCoin 的最新行情数据: #{symbols_with_usdt.join(', ')}。" \
    "对于每个资产，提供：当前价格、15分钟涨跌幅、RSI、成交量等信息。"
  end

  # 构建用于 MCP 数据获取的 Swarm
  def build_mcp_swarm
    SwarmSDK.build do
      name "MCP Data Fetcher"
      lead :fetcher

      agent :fetcher do
        model "claude-sonnet-4-6"
        description "使用 MCP 获取加密货币市场数据"

        mcp_server :tradingview_mcp,
          type: :stdio,
          command: "uv",
          args: [
            "tool", "run", "--from",
            "git+https://github.com/atilaahmettaner/tradingview-mcp.git",
            "tradingview-mcp"
          ]

        tools :Read, :Write, :Bash
      end
    end
  end

  # 解析 MCP 响应
  def parse_mcp_response(content)
    data = []

    # 匹配格式: **SYMBOL** - 涨幅 X.XX%
    content.scan(/\*\*(\w+USDT)\*\*\s*-\s*涨幅\s*([\d\.]+)%/) do |match|
      symbol = match[0]
      change_percent = match[1].to_f

      # 提取该资产的其他信息
      asset_block = content.split("**#{symbol}**").last
      if asset_block
        # 提取价格: 当前价格: $X.XXXX
        price = asset_block[/当前价格:\s*\$([\d\.]+)/, 1]&.to_f || 0.0

        # 提取 RSI: RSI: XX.XX
        rsi = asset_block[/RSI:\s*([\d\.]+)/, 1]&.to_f

        # 提取成交量: 成交量: X,XXX,XXX
        volume_str = asset_block[/成交量:\s*([\d,]+)/, 1]
        volume = volume_str&.gsub(",", "")&.to_i
      end

      data << {
        symbol: symbol,
        change_percent: change_percent,
        price: price,
        rsi: rsi,
        volume_24h: volume,
        exchange: "KUCOIN",
        timeframe: "15m"
      }
    end

    data
  end

  # ============================================================================
  # Phase 2: 保存到资产表
  # ============================================================================
  def execute_phase_2_save_to_assets(mcp_data)
    log_phase_start("Phase 2: 保存到资产表")

    assets = []

    mcp_data.each do |data|
      # 查找或创建 Asset
      asset = Asset.find_or_initialize_by(symbol: data[:symbol])

      if asset.new_record?
        asset.name = data[:symbol].gsub("USDT", "")
        asset.asset_type = "crypto"
        asset.save!
        log "[DB] 创建新资产: #{asset.symbol} (ID: #{asset.id})"
      else
        log "[DB] 找到现有资产: #{asset.symbol} (ID: #{asset.id})"
      end

      # 创建 AssetSnapshot
      snapshot = asset.asset_snapshots.create!(
        price: fetch_price_from_mcp_data(data),
        volume: data[:volume_24h],
        change_percent: data[:change_percent],
        captured_at: Time.current
      )

      log "[DB] 创建快照: #{asset.symbol} @ $#{snapshot.price}, 变化: #{snapshot.change_percent}%"

      assets << asset
    end

    log_phase_end("Phase 2", "成功保存 #{assets.length} 个资产")
    assets
  end

  def fetch_price_from_mcp_data(data)
    # 如果 MCP 返回了价格数据，直接使用
    # 否则需要从 TradingView MCP 单独获取
    data[:price] || 0.0
  end

  # ============================================================================
  # Phase 3: 计算因子
  # ============================================================================
  def execute_phase_3_calculate_factors(assets)
    log_phase_start("Phase 3: 计算因子")

    factor_count = 0

    # 确保有因子定义
    ensure_factor_definitions_exist

    assets.each do |asset|
      snapshots = asset.snapshots_in_period(hours: 168) # 7天数据
      latest_snapshot = asset.latest_snapshot

      # 保存 change_15m 因子 (只需要最新快照)
      if latest_snapshot&.change_percent.present?
        change_15m_def = FactorDefinition.find_by(code: "change_15m")
        if change_15m_def
          value = latest_snapshot.change_percent
          normalized_value = normalize_factor_value(value, change_15m_def)
          percentile = calculate_percentile(value, change_15m_def)

          FactorValue.create!(
            asset: asset,
            factor_definition: change_15m_def,
            raw_value: value,
            normalized_value: normalized_value,
            percentile: percentile,
            calculated_at: Time.current
          )
          factor_count += 1
          log "[Factor] #{asset.symbol}: change_15m = #{value.round(2)}%"
        end
      end

      # 历史数据因子需要至少 2 个快照
      next if snapshots.count < 2

      prices = snapshots.map(&:price)
      changes = snapshots.map(&:change_percent).compact

      # 计算各种因子
      factors_to_calculate = [
        { code: "momentum_7d", method: :calculate_momentum_7d, params: [prices] },
        { code: "momentum_30d", method: :calculate_momentum_30d, params: [prices] },
        { code: "volatility_7d", method: :calculate_volatility_7d, params: [prices] },
        { code: "rsi_14", method: :calculate_rsi_14, params: [prices] },
        { code: "bb_position", method: :calculate_bb_position, params: [prices] }
      ]

      factors_to_calculate.each do |factor_def|
        factor_definition = FactorDefinition.find_by(code: factor_def[:code])
        next unless factor_definition

        value = send(factor_def[:method], *factor_def[:params])
        next if value.nil?

        # 计算标准化值和百分位
        normalized_value = normalize_factor_value(value, factor_definition)
        percentile = calculate_percentile(value, factor_definition)

        FactorValue.create!(
          asset: asset,
          factor_definition: factor_definition,
          raw_value: value,
          normalized_value: normalized_value,
          percentile: percentile,
          calculated_at: Time.current
        )

        factor_count += 1
      end

      log "[Factor] 资产 #{asset.symbol} 计算完成, 共 #{factors_to_calculate.count + 1} 个因子"
    end

    log_phase_end("Phase 3", "共计算 #{factor_count} 个因子")
  end

  # 确保因子定义存在
  def ensure_factor_definitions_exist
    default_factors = [
      { code: "momentum_7d", name: "7日动量", category: "momentum", weight: 0.15 },
      { code: "momentum_30d", name: "30日动量", category: "momentum", weight: 0.15 },
      { code: "volatility_7d", name: "7日波动率", category: "risk", weight: 0.1 },
      { code: "rsi_14", name: "RSI(14)", category: "technical", weight: 0.2 },
      { code: "bb_position", name: "布林带位置", category: "technical", weight: 0.1 },
      { code: "change_15m", name: "15分钟涨跌幅", category: "momentum", weight: 0.2 }
    ]

    default_factors.each do |factor_data|
      FactorDefinition.find_or_create_by!(code: factor_data[:code]) do |fd|
        fd.name = factor_data[:name]
        fd.category = factor_data[:category]
        fd.weight = factor_data[:weight]
        fd.calculation_method = "custom"
        fd.active = true
      end
    end
  end

  # 因子计算方法
  def calculate_momentum_7d(prices)
    return nil if prices.length < 8
    (prices.last - prices[-8]) / prices[-8] * 100
  end

  def calculate_momentum_30d(prices)
    return nil if prices.length < 30
    (prices.last - prices[-30]) / prices[-30] * 100
  end

  def calculate_volatility_7d(prices)
    return nil if prices.length < 8
    returns = prices[-7..-1].each_cons(2).map { |a, b| (b - a) / a }
    mean = returns.sum / returns.length
    variance = returns.map { |r| (r - mean)**2 }.sum / returns.length
    Math.sqrt(variance) * 100
  end

  def calculate_rsi_14(prices)
    return nil if prices.length < 15
    gains = []
    losses = []

    prices[-14..-1].each_cons(2) do |a, b|
      change = b - a
      if change > 0
        gains << change
        losses << 0
      else
        gains << 0
        losses << change.abs
      end
    end

    avg_gain = gains.sum / 14.0
    avg_loss = losses.sum / 14.0

    return 100 if avg_loss == 0
    rs = avg_gain / avg_loss
    100 - (100 / (1 + rs))
  end

  def calculate_bb_position(prices)
    return nil if prices.length < 20
    period = 20
    recent_prices = prices[-period..-1]
    sma = recent_prices.sum / period
    variance = recent_prices.map { |p| (p - sma)**2 }.sum / period
    std_dev = Math.sqrt(variance)

    upper_band = sma + (2 * std_dev)
    lower_band = sma - (2 * std_dev)

    return 0.5 if upper_band == lower_band
    (prices.last - lower_band) / (upper_band - lower_band)
  end

  def calculate_change_15m(changes)
    return nil if changes.empty?
    changes.last
  end

  # 标准化因子值
  def normalize_factor_value(value, factor_definition)
    # 根据因子类型使用不同的标准化方法
    case factor_definition.code
    when /momentum|change/
      # 动量因子: -100 到 100 映射到 -1 到 1
      [[value / 100.0, 1.0].min, -1.0].max
    when /volatility/
      # 波动率: 0-100 映射到 0-1，越高风险越大
      [[value / 100.0, 1.0].min, 0.0].max
    when /rsi/
      # RSI: 0-100 映射到 -1 到 1，50为0
      (value - 50) / 50.0
    when /bb_position/
      # 布林带位置: 0-1 映射到 -1 到 1
      (value - 0.5) * 2
    else
      # 默认: 除以 100
      value / 100.0
    end
  end

  # 计算百分位
  def calculate_percentile(value, factor_definition)
    # 这里简化处理，实际应该基于历史数据计算
    # 返回 0-100 之间的值
    case factor_definition.code
    when /rsi/
      value
    when /bb_position/
      value * 100
    else
      # 默认使用正态分布近似
      # 将值映射到 0-100
      normalized = normalize_factor_value(value, factor_definition)
      ((normalized + 1) / 2 * 100).clamp(0, 100)
    end
  end

  # ============================================================================
  # Phase 4: 信号生成 (不依赖策略，纯因子驱动)
  # ============================================================================
  def execute_phase_4_generate_signals(assets)
    log_phase_start("Phase 4: 信号生成")

    buy_count = 0
    sell_count = 0
    hold_count = 0

    assets.each do |asset|
      # 获取最新的因子值
      factor_values = FactorValue.where(asset: asset)
        .where("calculated_at > ?", 1.hour.ago)
        .index_by { |fv| fv.factor_definition.code }

      next if factor_values.empty?

      # 生成信号（基于因子，不依赖策略）
      signal_data = calculate_signal_from_factors(asset, factor_values)

      # 保存信号
      TradingSignal.create!(
        asset: asset,
        signal_type: signal_data[:type],
        confidence: signal_data[:confidence],
        reasoning: signal_data[:reasoning],
        generated_at: Time.current,
        factor_snapshot: factor_values.transform_values { |v| v.raw_value }
      )

      case signal_data[:type]
      when "buy" then buy_count += 1
      when "sell" then sell_count += 1
      else hold_count += 1
      end

      log "[Signal] #{asset.symbol}: #{signal_data[:type].upcase} (置信度: #{signal_data[:confidence].round(2)})"
    end

    log "[Signal] 信号生成完成: #{buy_count} buy, #{sell_count} sell, #{hold_count} hold"
    log_phase_end("Phase 4", "信号生成完成")

    { buy: buy_count, sell: sell_count, hold: hold_count }
  end

  # 判断市场环境（基于因子，独立判断）
  def determine_market_condition(factor_values)
    volatility = factor_values["volatility_7d"]&.raw_value || 0
    momentum = factor_values["momentum_7d"]&.raw_value || 0
    rsi = factor_values["rsi_14"]&.raw_value || 50

    if volatility > 80 && momentum < -10
      "crash"
    elsif volatility > 60 && momentum > 20
      "bubble"
    elsif volatility > 50
      "volatile"
    else
      "normal"
    end
  end

  # 基于因子计算信号（不依赖策略参数）
  def calculate_signal_from_factors(asset, factor_values)
    # 获取因子值
    momentum_7d = factor_values["momentum_7d"]&.raw_value || 0
    rsi = factor_values["rsi_14"]&.raw_value || 50
    bb_position = factor_values["bb_position"]&.raw_value || 0.5
    change_15m = factor_values["change_15m"]&.raw_value || 0
    volatility = factor_values["volatility_7d"]&.raw_value || 0

    # 信号评分
    buy_score = 0
    sell_score = 0
    reasons = []

    # 动量因子
    if momentum_7d > 10
      buy_score += 2
      reasons << "7日动量强劲(#{momentum_7d.round(2)}%)"
    elsif momentum_7d < -10
      sell_score += 2
      reasons << "7日动量疲软(#{momentum_7d.round(2)}%)"
    end

    # RSI 因子
    if rsi < 30
      buy_score += 2
      reasons << "RSI超卖(#{rsi.round(1)})"
    elsif rsi > 70
      sell_score += 2
      reasons << "RSI超买(#{rsi.round(1)})"
    end

    # 布林带位置
    if bb_position < 0.2
      buy_score += 1
      reasons << "价格接近布林带下轨"
    elsif bb_position > 0.8
      sell_score += 1
      reasons << "价格接近布林带上轨"
    end

    # 15分钟变化
    if change_15m > 5
      buy_score += 1
      reasons << "15分钟涨幅强劲(#{change_15m.round(2)}%)"
    elsif change_15m < -5
      sell_score += 1
      reasons << "15分钟跌幅较大(#{change_15m.round(2)}%)"
    end

    # 波动率调整（高波动时降低置信度）
    volatility_penalty = volatility > 50 ? 0.1 : 0

    # 确定信号类型和置信度
    if buy_score >= 3 && buy_score > sell_score
      {
        type: "buy",
        confidence: [(buy_score / 6.0 - volatility_penalty), 0.95].min,
        reasoning: "买入信号: #{reasons.join('; ')}"
      }
    elsif sell_score >= 3 && sell_score > buy_score
      {
        type: "sell",
        confidence: [(sell_score / 6.0 - volatility_penalty), 0.95].min,
        reasoning: "卖出信号: #{reasons.join('; ')}"
      }
    else
      {
        type: "hold",
        confidence: 0.5,
        reasoning: "持有观望: #{reasons.empty? ? '多空信号均衡' : reasons.join('; ')}"
      }
    end
  end

  # ============================================================================
  # Phase 5: AI 策略建议 (独立于 Trader/Strategy，基于资产分析给出建议)
  # ============================================================================
  def execute_phase_5_ai_recommendation(assets, signals)
    log_phase_start("Phase 5: AI 策略建议")

    # 构建资产分析数据
    assets_analysis = build_assets_analysis_for_ai(assets)

    # 调用 AI 生成策略建议
    recommendation = call_ai_for_recommendation(assets_analysis, signals)

    log "[AI] 市场环境: #{recommendation[:market_analysis]}"
    log "[AI] 建议操作: #{recommendation[:suggested_actions]&.length || 0} 个"
    log "[AI] 风险等级: #{recommendation[:risk_level]}"

    log_phase_end("Phase 5", "AI 建议生成完成")

    recommendation
  end

  # 构建资产分析数据
  def build_assets_analysis_for_ai(assets)
    assets.map do |asset|
      snapshot = asset.latest_snapshot
      latest_signal = TradingSignal.where(asset: asset).order(generated_at: :desc).first
      latest_factors = FactorValue.where(asset: asset)
        .where("calculated_at > ?", 1.hour.ago)
        .includes(:factor_definition)
        .map do |fv|
          {
            code: fv.factor_definition.code,
            name: fv.factor_definition.name,
            value: fv.raw_value,
            normalized: fv.normalized_value,
            percentile: fv.percentile
          }
        end

      {
        symbol: asset.symbol,
        name: asset.name,
        asset_type: asset.asset_type,
        price: snapshot&.price,
        change_percent: snapshot&.change_percent,
        signal: latest_signal&.signal_type,
        confidence: latest_signal&.confidence,
        reasoning: latest_signal&.reasoning,
        factors: latest_factors
      }
    end
  end

  # 调用 AI 生成建议
  def call_ai_for_recommendation(assets_analysis, signals)
    context = build_ai_context(assets_analysis, signals)
    swarm = build_analysis_swarm
    result = swarm.execute(context)

    parse_ai_recommendation(result&.content || result.to_s)
  end

  # 构建 AI 上下文
  def build_ai_context(assets_analysis, signals)
    <<~CONTEXT
      ## 分析请求

      请分析以下资产数据，提供：
      1. 市场环境判断（normal/volatile/crash/bubble）
      2. 每个资产的操作建议（buy/sell/hold）
      3. 建议的仓位配置（基于风险偏好）
      4. 具体的策略参数建议

      ## 用户配置
      - 可用资金: $#{number_with_delimiter(@options[:capital].round(0))}
      - 风险偏好: #{@options[:risk_preference]} (conservative=保守, balanced=平衡, aggressive=激进)
      - 分析的资产数量: #{assets_analysis.length}

      ## 信号摘要
      - 买入信号: #{signals[:buy]} 个
      - 卖出信号: #{signals[:sell]} 个
      - 持有信号: #{signals[:hold]} 个

      ## 资产详细数据
      #{format_assets_analysis_for_ai(assets_analysis)}

      ## 输出要求

      请以 JSON 格式输出，结构如下：
      ```json
      {
        "market_analysis": "市场环境分析（1-2句话）",
        "market_condition": "normal 或 volatile 或 crash 或 bubble",
        "risk_level": "low 或 medium 或 high",
        "suggested_actions": [
          {
            "symbol": "BTC",
            "action": "buy 或 sell 或 hold",
            "confidence": 0.8,
            "suggested_allocation_percent": 30,
            "reason": "建议理由"
          }
        ],
        "strategy_recommendations": {
          "max_positions": 5,
          "buy_signal_threshold": 0.6,
          "max_position_size": 0.25,
          "min_cash_reserve": 0.2,
          "reasoning": "策略参数建议理由"
        },
        "overall_summary": "整体建议摘要",
        "risk_warnings": ["风险提示1", "风险提示2"]
      }
      ```
    CONTEXT
  end

  # 格式化资产分析数据
  def format_assets_analysis_for_ai(assets_analysis)
    assets_analysis.map do |data|
      factors_str = if data[:factors]&.any?
        data[:factors].map { |f| "  - #{f[:name]}: #{f[:value]&.round(2)} (百分位: #{f[:percentile]}%)" }.join("\n")
      else
        "  暂无因子数据"
      end

      <<~ASSET
        ### #{data[:name]} (#{data[:symbol]})
        - 类型: #{data[:asset_type]}
        - 当前价格: $#{data[:price]&.round(2) || 'N/A'}
        - 变化: #{data[:change_percent]&.round(2) || 0}%
        - 信号: #{data[:signal]&.upcase || 'N/A'} (置信度: #{(data[:confidence] * 100).round(1) if data[:confidence]}%)
        - 因子数据:
        #{factors_str}
      ASSET
    end.join("\n")
  end

  # 构建分析 Swarm
  def build_analysis_swarm
    SwarmSDK.build do
      name "Asset Analysis Advisor"
      lead :analyst

      agent :analyst do
        model "claude-sonnet-4-6"
        description "独立资产分析顾问，基于因子和信号提供策略建议"

        system_prompt <<~PROMPT
          你是 SmartTrader 的独立资产分析顾问。你的职责是：

          1. **市场分析**：基于因子数据判断市场环境
             - normal: 因子值正常，波动适中
             - volatile: 波动率因子偏高（>70%百分位）
             - crash: 多数因子为负，市场恐慌
             - bubble: 动量过热，情绪因子极端

          2. **信号评估**：
             - 高置信度信号（>0.7）值得跟随
             - 低置信度信号应谨慎对待
             - 多因子共振时信号更可靠

          3. **配置建议**：
             - 根据风险偏好调整仓位
             - conservative: 单资产不超过15%，现金保留30%+
             - balanced: 单资产不超过25%，现金保留20%+
             - aggressive: 单资产不超过40%，现金保留10%+

          4. **策略参数建议**：
             - 基于当前市场环境建议策略参数
             - 考虑风险偏好调整阈值

          请严格按 JSON 格式输出建议。
        PROMPT
      end
    end
  end

  # 解析 AI 推荐结果
  def parse_ai_recommendation(content)
    return default_recommendation if content.blank?

    # 尝试从 Markdown 代码块中提取 JSON
    if content =~ /```(?:json)?\s*(\{.*\})\s*```/m
      content = Regexp.last_match(1)
    end

    # 找到 JSON 对象
    start_index = content.index("{")
    end_index = content.rindex("}")

    if start_index && end_index && end_index > start_index
      json_str = content[start_index..end_index]
      result = JSON.parse(json_str, symbolize_names: true)

      # 添加原始内容和时间戳
      result[:raw_content] = content
      result[:generated_at] = Time.current
      return result
    end

    # 如果不是 JSON，从文本中提取
    parse_text_recommendation(content)
  rescue JSON::ParserError => e
    log "[AI] JSON 解析错误: #{e.message}"
    parse_text_recommendation(content)
  end

  # 从文本中提取推荐
  def parse_text_recommendation(content)
    market_analysis = content[/市场环境[：:]\s*(.+?)(?:\n|$)/im, 1] ||
                      content[/市场分析[：:]\s*(.+?)(?:\n|$)/im, 1] ||
                      "AI 分析完成"

    {
      market_analysis: market_analysis.strip,
      market_condition: determine_condition_from_text(content),
      risk_level: determine_risk_from_text(content),
      suggested_actions: extract_actions_from_text(content),
      strategy_recommendations: {
        max_positions: 5,
        buy_signal_threshold: 0.6,
        max_position_size: @options[:risk_preference] == "aggressive" ? 0.4 : 0.25,
        min_cash_reserve: @options[:risk_preference] == "conservative" ? 0.3 : 0.2,
        reasoning: "基于 AI 分析的保守建议"
      },
      overall_summary: "AI 建议持有现金观望，等待更好的入场时机",
      risk_warnings: ["市场波动较大，请注意风险控制"],
      raw_content: content[0..1000],
      generated_at: Time.current
    }
  end

  # 从文本判断市场环境
  def determine_condition_from_text(content)
    return "crash" if content =~ /崩盘|暴跌|恐慌/i
    return "bubble" if content =~ /泡沫|过热|泡沫/i
    return "volatile" if content =~ /波动|震荡|不稳定/i
    "normal"
  end

  # 从文本判断风险等级
  def determine_risk_from_text(content)
    return "high" if content =~ /高风险|风险较高|谨慎/i
    return "low" if content =~ /低风险|安全|稳定/i
    "medium"
  end

  # 从文本提取操作建议
  def extract_actions_from_text(content)
    actions = []
    @symbols.each do |symbol|
      if content =~ /#{symbol}.*买入|#{symbol}.*buy/i
        actions << { symbol: symbol, action: "buy", confidence: 0.6, reason: "AI 分析建议买入" }
      elsif content =~ /#{symbol}.*卖出|#{symbol}.*sell/i
        actions << { symbol: symbol, action: "sell", confidence: 0.6, reason: "AI 分析建议卖出" }
      else
        actions << { symbol: symbol, action: "hold", confidence: 0.5, reason: "持有观望" }
      end
    end
    actions
  end

  # 默认推荐（当 AI 调用失败时）
  def default_recommendation
    {
      market_analysis: "数据获取不完整，建议谨慎操作",
      market_condition: "normal",
      risk_level: "medium",
      suggested_actions: @symbols.map { |s| { symbol: s, action: "hold", confidence: 0.5, reason: "数据不完整，建议观望" } },
      strategy_recommendations: {
        max_positions: 5,
        buy_signal_threshold: 0.7,
        max_position_size: 0.2,
        min_cash_reserve: 0.3,
        reasoning: "默认保守策略"
      },
      overall_summary: "建议保持谨慎，持有现金观望",
      risk_warnings: ["数据不完整，建议等待更多信息"],
      generated_at: Time.current
    }
  end

  # ============================================================================
  # 日志方法
  # ============================================================================
  def log(message)
    @logs << "[#{Time.current.strftime('%Y-%m-%d %H:%M:%S')}] #{message}"
    Rails.logger.info message
    puts message # 同时输出到控制台
  end

  def log_phase_start(phase_name)
    log "=" * 80
    log "[#{phase_name}] 开始"
    log "-" * 80
  end

  def log_phase_end(phase_name, result)
    log "-" * 80
    log "[#{phase_name}] 结束 - #{result}"
    log "=" * 80
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
