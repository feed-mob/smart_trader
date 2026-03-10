# frozen_string_literal: true

class StrategyGeneratorService
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
    TradingStrategy.market_conditions.keys.map do |market_condition|
      generate_single_strategy_with_ai(market_condition)
    end
  end

  def generate_single_strategy_with_ai(market_condition)
    prompt = build_prompt(market_condition)
    response = strategy_agent.ask(prompt)
    parse_llm_response(response.content, market_condition)
  end

  def strategy_agent
    @strategy_agent ||= StrategyAgent.new
  end

  def build_prompt(market_condition)
    <<~PROMPT
      投资者描述：
      "#{@description}"

      风险偏好：#{@risk_level || 'balanced'}
      市场环境：#{market_condition}

      请返回策略参数。
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
