# frozen_string_literal: true

class StrategyGeneratorService
  SYSTEM_INSTRUCTIONS = <<~PROMPT
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

    请根据给定的风险偏好和市场环境，生成以下参数：
    1. 策略名称（简短描述，如"稳健价值投资策略"）
    2. 最大持仓数（2-5个资产）
    3. 买入信号阈值（0.3-0.7，数值越高越严格）
    4. 单个资产最大仓位（0.3-0.7，即30%-70%）
    5. 最小现金保留比例（0.05-0.4，即5%-40%）
    6. 策略说明（1-2句话，针对当前市场环境）

    注意：
    - 参数必须在合理范围内
    - 保守型投资者：持仓少、阈值高、仓位小、现金多
    - 激进型投资者：持仓多、阈值低、仓位大、现金少
    - 崩盘时：保守型应防守保本，激进型应逆向买入
    - 泡沫时：保守型应获利了结，激进型可趋势跟随
  PROMPT

  def initialize(description, risk_level: nil)
    @description = description&.strip
    @risk_level = risk_level
  end

  # Generate a single strategy (for backward compatibility)
  def call
    generate_strategies.first || fallback_strategies.first
  end

  # Generate strategies for all market conditions
  def generate_strategies
    if @description.present?
      generate_all_with_ai
    else
      fallback_strategies
    end
  end

  private

  def generate_all_with_ai
    strategies = []
    TradingStrategy.market_conditions.keys.each do |market_condition|
      strategies << generate_single_strategy_with_ai(market_condition)
    end
    strategies
  end

  def generate_single_strategy_with_ai(market_condition)
    ai_service = AiChatService.new(
      instructions: SYSTEM_INSTRUCTIONS,
      temperature: 0.3,
      max_tokens: 500
    )

    response = ai_service.ask(user_prompt_for(market_condition))
    parse_llm_response(response, market_condition)
  end

  def user_prompt_for(market_condition)
    <<~PROMPT
      投资者描述：
      "#{@description}"

      风险偏好：#{@risk_level || 'balanced'}
      市场环境：#{market_condition}

      请严格按照以下 JSON 格式返回策略参数，不要添加任何 markdown 标记或其他文字：
      {"name":"策略名称","max_positions":3,"buy_signal_threshold":0.5,"max_position_size":0.5,"min_cash_reserve":0.2,"description":"针对#{market_condition}市场的策略说明"}
    PROMPT
  end

  def parse_llm_response(content, market_condition)
    clean_content = content.to_s.gsub(/```json\s*|\s*```/i, "").strip
    json_match = clean_content.match(/\{[^{}]*\}/)

    data = JSON.parse(json_match[0])
    build_strategy_params(data, market_condition)
  end

  def build_strategy_params(data, market_condition)
    {
      name: sanitize_name(data["name"]),
      risk_level: @risk_level || sanitize_risk_level(data["risk_level"]),
      max_positions: sanitize_max_positions(data["max_positions"]),
      buy_signal_threshold: sanitize_threshold(data["buy_signal_threshold"], 0.3, 0.7),
      max_position_size: sanitize_threshold(data["max_position_size"], 0.3, 0.7),
      min_cash_reserve: sanitize_threshold(data["min_cash_reserve"], 0.05, 0.4),
      description: sanitize_description(data["description"]),
      market_condition: market_condition,
      generated_by: :llm
    }
  end

  def sanitize_name(name)
    name.to_s.strip[0..99].presence || "AI生成策略"
  end

  def sanitize_risk_level(level)
    valid_levels = %w[conservative balanced aggressive]
    valid_levels.include?(level.to_s.downcase) ? level.to_sym : :balanced
  end

  def sanitize_max_positions(value)
    [[value.to_i, 2].max, 5].min
  end

  def sanitize_threshold(value, min_value, max_value)
    [[value.to_f, min_value].max, max_value].min.round(2)
  end

  def sanitize_description(desc)
    desc.to_s.strip[0..499].presence || "AI 根据投资风格描述自动生成"
  end

  def fallback_strategies
    TradingStrategy.market_conditions.keys.map do |market_condition|
      build_matrix_strategy(market_condition)
    end
  end

  def build_matrix_strategy(market_condition)
    matrix_params = TradingStrategy.strategy_for(@risk_level || :balanced, market_condition)
    {
      name: matrix_params[:name],
      risk_level: @risk_level || :balanced,
      max_positions: matrix_params[:max_positions],
      buy_signal_threshold: matrix_params[:buy_signal_threshold],
      max_position_size: matrix_params[:max_position_size],
      min_cash_reserve: matrix_params[:min_cash_reserve],
      description: matrix_params[:description],
      market_condition: market_condition,
      generated_by: :matrix
    }
  end
end
