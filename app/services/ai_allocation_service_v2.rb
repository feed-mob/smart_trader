# frozen_string_literal: true

# AI 资产分析服务 V2 - 使用 SwarmSDK Tool 调用方式
#
# 核心设计理念：
# - AI Agent 通过调用 Tools 动态获取需要的数据
# - 使用现有的 FactorDefinition 进行因子分析
# - 通过 MCP 获取市场数据
#
# 使用方式：
#   service = AiAllocationServiceV2.new(symbols: ["BTC", "ETH"], capital: 100000)
#   result = service.run_full_pipeline
#
class AiAllocationServiceV2
  attr_reader :logs

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

    # Phase 3-5: 使用 SwarmSDK 让 AI Agent 完成因子分析、信号生成、策略建议
    analysis_result = call_swarm_for_analysis(assets)

    log "=" * 80
    log "[AiAllocationServiceV2] 资产分析流程执行完成"
    log "=" * 80

    {
      logs: @logs,
      mcp_data: mcp_data,
      assets: assets,
      signals: analysis_result[:signals],
      recommendation: analysis_result[:recommendation],
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
    mcp_data = if @symbols.any?
      fetch_specific_assets_data
    else
      # 否则获取热门资产
      fetch_top_gainers_data
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

    swarm = build_mcp_fetcher_swarm
    prompt = build_fetch_prompt_for_symbols
    result = swarm.execute(prompt)

    parse_mcp_response(result&.content || result.to_s)
  end

  # 获取涨幅最大的资产
  def fetch_top_gainers_data
    log "[MCP] 获取热门涨幅资产..."

    swarm = build_mcp_fetcher_swarm
    result = swarm.execute("获取 KuCoin 上过去15分钟涨幅最大的10个加密货币")

    parse_mcp_response(result&.content || result.to_s)
  end

  # 构建获取指定资产的 prompt
  def build_fetch_prompt_for_symbols
    symbols_with_usdt = @symbols.map { |s| s.end_with?("USDT") ? s : "#{s}USDT" }
    "获取以下加密货币在 KuCoin 的最新行情数据: #{symbols_with_usdt.join(', ')}。" \
    "对于每个资产，提供：当前价格、15分钟涨跌幅、RSI、成交量等信息。"
  end

  # 构建 MCP 数据获取的 Swarm
  def build_mcp_fetcher_swarm
    SwarmSDK.build do
      name "MCP Data Fetcher"
      lead :fetcher

      agent :fetcher do
        model "gpt-5.2"
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
        asset.exchange = data[:exchange] || "KUCOIN"
        asset.quote_currency = "USDT"
        asset.save!
        log "[DB] 创建新资产: #{asset.symbol} (ID: #{asset.id})"
      else
        log "[DB] 找到现有资产: #{asset.symbol} (ID: #{asset.id})"
      end

      # 创建 AssetSnapshot
      snapshot = asset.asset_snapshots.create!(
        price: data[:price] || 0.0,
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

  # ============================================================================
  # Phase 3-5: 使用 SwarmSDK 完成分析和建议
  # ============================================================================
  def call_swarm_for_analysis(assets)
    log_phase_start("Phase 3-5: Swarm 分析")

    swarm = build_analysis_swarm
    prompt = build_analysis_prompt(assets)
    result = swarm.execute(prompt)

    log "[Swarm] 分析完成，解析结果..."
    parse_swarm_result(result, assets)
  end

  # 构建分析 prompt
  def build_analysis_prompt(assets)
    asset_symbols = assets.map(&:symbol)
    active_factors = FactorDefinition.active.ordered.pluck(:code, :name, :category)

    <<~PROMPT
      请为以下资产执行完整的分析流程：

      ## 分析目标
      资产列表: #{asset_symbols.join(', ')}
      可用资金: $#{number_with_delimiter(@options[:capital].round(0))}
      风险偏好: #{@options[:risk_preference]}

      ## 可用的因子定义
      系统中已配置以下活跃因子：
      #{active_factors.map { |code, name, category| "  - #{code}: #{name} (#{category})" }.join("\n")}

      ## 请按以下步骤操作：

      ### Step 1: 计算因子
      使用 CalculateFactors 工具为每个资产计算因子值。
      该工具会自动使用现有的 FactorDefinition 配置进行计算。

      ### Step 2: 生成信号
      使用 GenerateSignals 工具基于因子数据生成交易信号。
      信号类型: buy(买入)、sell(卖出)、hold(持有)

      ### Step 3: 获取分析数据
      使用 GetFactorData 工具获取因子数据（可按类别或百分位筛选）。
      使用 GetSignalData 工具获取信号数据（可按置信度筛选）。

      ### Step 4: 生成配置建议
      根据因子和信号数据，为用户生成资产配置建议。

      ## 市场环境判断标准
      - normal: 因子值正常，波动适中
      - volatile: 波动率因子偏高（percentile > 70）
      - crash: 多数因子为负，市场恐慌
      - bubble: 动量过热，情绪因子极端

      ## 配置约束
      根据风险偏好：
      - conservative: 单资产不超过15%，现金保留30%+
      - balanced: 单资产不超过25%，现金保留20%+
      - aggressive: 单资产不超过40%，现金保留10%+

      ## 输出格式要求
      你的最终回复必须只包含一个 JSON 对象：
      ```json
      {
        "market_analysis": "市场环境分析（1-2句话）",
        "market_condition": "normal 或 volatile 或 crash 或 bubble",
        "risk_level": "low 或 medium 或 high",
        "signals_summary": {
          "buy": 0,
          "sell": 0,
          "hold": 0
        },
        "allocations": [
          {
            "symbol": "BTCUSDT",
            "action": "buy 或 sell 或 hold",
            "allocation_percent": 30,
            "amount_usd": 30000,
            "confidence": 0.8,
            "reason": "配置理由"
          }
        ],
        "cash_reserve": {
          "percent": 20,
          "amount_usd": 20000
        },
        "strategy_recommendations": {
          "max_positions": 5,
          "buy_signal_threshold": 0.6,
          "max_position_size": 0.25,
          "min_cash_reserve": 0.2,
          "reasoning": "策略参数建议理由"
        },
        "risk_warnings": ["风险提示1", "风险提示2"],
        "detailed_reasoning": "详细解释（3-5句话）"
      }
      ```

      注意：
      - 如果没有合适的买入机会，allocations 为空数组 []
      - allocation_percent + cash_reserve.percent = 100
    PROMPT
  end

  # 构建分析 Swarm
  def build_analysis_swarm
    SwarmSDK.build do
      name "Asset Analysis Advisor"
      lead :analyst

      # 分析师 Agent - 通过 Tools 获取数据并决策
      agent :analyst do
        model "gpt-5.2"
        description "资产分析顾问，通过调用 Tools 计算因子、生成信号并提供策略建议"

        system_prompt <<~PROMPT
          你是 SmartTrader 的资产分析顾问。你的职责是：

          ## 核心任务
          1. 使用 CalculateFactors 工具为资产计算因子（基于现有的 FactorDefinition）
          2. 使用 GenerateSignals 工具生成交易信号
          3. 使用 GetFactorData 工具获取因子数据
          4. 使用 GetSignalData 工具获取信号数据
          5. 综合分析后生成配置建议

          ## 因子分析指南
          - 使用数据库中已有的 FactorDefinition 进行分析
          - 不同类别的因子提供不同维度的信息：
            - technical: 技术指标（RSI、MACD 等）
            - momentum: 动量因子（价格变化率）
            - risk: 风险因子（波动率）
            - volume: 成交量因子
          - 因子的 percentile 表示相对历史位置

          ## 信号评估
          - 高置信度信号（>0.7）值得跟随
          - 低置信度信号应谨慎对待
          - 多因子共振时信号更可靠

          ## 市场环境判断
          根据 factor 数据判断：
          - normal: 因子值正常，波动适中
          - volatile: 波动率因子偏高（percentile > 70）
          - crash: 多数因子为负，市场恐慌
          - bubble: 动量过热，情绪因子极端

          ## 配置建议原则
          根据风险偏好调整仓位：
          - conservative: 单资产不超过15%，现金保留30%+
          - balanced: 单资产不超过25%，现金保留20%+
          - aggressive: 单资产不超过40%，现金保留10%+

          ## 输出格式
          你的最终回复必须是一个有效的 JSON 对象，严格按照用户要求的格式。
          不要在 JSON 之外添加任何额外文字说明。
        PROMPT

        # 使用现有的 Tools 以及新的因子计算和信号生成工具
        tools :CalculateFactors, :GenerateSignals, :GetFactorData, :GetSignalData, :ListAssets
      end
    end
  end

  # 解析 Swarm 结果
  def parse_swarm_result(result, assets)
    content = result&.content || result.to_s

    # 解析信号摘要
    signals = extract_signals_from_result(content, assets)

    # 解析推荐配置
    recommendation = parse_recommendation(content)

    log "[Swarm] 信号生成: #{signals[:buy]} buy, #{signals[:sell]} sell, #{signals[:hold]} hold"
    log "[Swarm] 市场环境: #{recommendation[:market_condition]}"
    log "[Swarm] 风险等级: #{recommendation[:risk_level]}"

    log_phase_end("Phase 3-5", "分析完成")

    {
      signals: signals,
      recommendation: recommendation
    }
  end

  # 从结果中提取信号
  def extract_signals_from_result(content, assets)
    # 尝试从 JSON 中提取 signals_summary
    if content =~ /"signals_summary"\s*:\s*\{([^}]+)\}/m
      summary_str = "{#{$1}}"
      begin
        summary = JSON.parse(summary_str)
        return {
          buy: summary["buy"] || 0,
          sell: summary["sell"] || 0,
          hold: summary["hold"] || 0
        }
      rescue JSON::ParserError
        # 继续使用默认方式
      end
    end

    # 统计数据库中实际的信号
    asset_ids = assets.map(&:id)
    signals_data = TradingSignal.where(asset_id: asset_ids)
      .where("generated_at > ?", 1.hour.ago)
      .group(:signal_type)
      .count

    {
      buy: signals_data["buy"] || 0,
      sell: signals_data["sell"] || 0,
      hold: signals_data["hold"] || 0
    }
  end

  # 解析推荐配置
  def parse_recommendation(content)
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

      # 确保必要字段存在
      result[:generated_at] = Time.current
      result[:raw_content] = content[0..500]
      return result
    end

    # 如果不是 JSON，从文本中提取
    parse_text_recommendation(content)
  rescue JSON::ParserError => e
    log "[Swarm] JSON 解析错误: #{e.message}"
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
      allocations: extract_allocations_from_text(content),
      strategy_recommendations: {
        max_positions: 5,
        buy_signal_threshold: 0.6,
        max_position_size: @options[:risk_preference] == "aggressive" ? 0.4 : 0.25,
        min_cash_reserve: @options[:risk_preference] == "conservative" ? 0.3 : 0.2,
        reasoning: "基于 AI 分析的保守建议"
      },
      cash_reserve: {
        percent: @options[:risk_preference] == "conservative" ? 30 : 20,
        amount_usd: (@options[:capital] * (@options[:risk_preference] == "conservative" ? 0.3 : 0.2)).round(0)
      },
      risk_warnings: [ "市场波动较大，请注意风险控制" ],
      overall_summary: "AI 建议持有现金观望，等待更好的入场时机",
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

  # 从文本提取配置建议
  def extract_allocations_from_text(content)
    actions = []
    @symbols.each do |symbol|
      symbol_usdt = symbol.end_with?("USDT") ? symbol : "#{symbol}USDT"
      if content =~ /#{symbol}.*买入|#{symbol_usdt}.*buy/i
        actions << { symbol: symbol_usdt, action: "buy", confidence: 0.6, reason: "AI 分析建议买入" }
      elsif content =~ /#{symbol}.*卖出|#{symbol_usdt}.*sell/i
        actions << { symbol: symbol_usdt, action: "sell", confidence: 0.6, reason: "AI 分析建议卖出" }
      else
        actions << { symbol: symbol_usdt, action: "hold", confidence: 0.5, reason: "持有观望" }
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
      allocations: @symbols.map do |s|
        { symbol: s.end_with?("USDT") ? s : "#{s}USDT", action: "hold", confidence: 0.5, reason: "数据不完整，建议观望" }
      end,
      strategy_recommendations: {
        max_positions: 5,
        buy_signal_threshold: 0.7,
        max_position_size: 0.2,
        min_cash_reserve: 0.3,
        reasoning: "默认保守策略"
      },
      cash_reserve: {
        percent: 30,
        amount_usd: (@options[:capital] * 0.3).round(0)
      },
      overall_summary: "建议保持谨慎，持有现金观望",
      risk_warnings: [ "数据不完整，建议等待更多信息" ],
      generated_at: Time.current
    }
  end

  # ============================================================================
  # 日志方法
  # ============================================================================
  def log(message)
    @logs << "[#{Time.current.strftime('%Y-%m-%d %H:%M:%S')}] #{message}"
    Rails.logger.info message
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
