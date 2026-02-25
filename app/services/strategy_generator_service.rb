# frozen_string_literal: true

class StrategyGeneratorService
  SYSTEM_INSTRUCTIONS = <<~PROMPT
    你是一位专业的投资顾问。根据投资者的描述，生成一套适合的交易策略参数。

    请分析投资者的风险偏好、投资目标和交易风格，生成以下参数：

    1. 策略名称（简短描述，如"稳健价值投资策略"）
    2. 风险等级（conservative/balanced/aggressive）
    3. 最大持仓数（2-5个资产）
    4. 买入信号阈值（0.3-0.7，数值越高越严格）
    5. 单个资产最大仓位（0.3-0.7，即30%-70%）
    6. 最小现金保留比例（0.05-0.4，即5%-40%）
    7. 策略说明（1-2句话）

    注意：
    - 参数必须在合理范围内
    - 保守型投资者：持仓少、阈值高、仓位小、现金多
    - 激进型投资者：持仓多、阈值低、仓位大、现金少
  PROMPT

  def initialize(description, risk_level: nil)
    @description = description&.strip
    @risk_level = risk_level
  end

  def call
    return fallback_strategy if @description.blank?

    generate_with_ai
  end

  private

  def generate_with_ai
    ai_service = AiChatService.new(
      instructions: SYSTEM_INSTRUCTIONS,
      temperature: 0.3,
      max_tokens: 500
    )

    response = ai_service.ask(user_prompt)
    parse_llm_response(response)
  end

  def user_prompt
    <<~PROMPT
      投资者描述：
      "#{@description}"

      请严格按照以下 JSON 格式返回策略参数，不要添加任何 markdown 标记或其他文字：
      {"name":"策略名称","risk_level":"conservative","max_positions":3,"buy_signal_threshold":0.5,"max_position_size":0.5,"min_cash_reserve":0.2,"description":"策略说明"}
    PROMPT
  end

  def parse_llm_response(content)
    clean_content = content.to_s.gsub(/```json\s*|\s*```/i, "").strip
    json_match = clean_content.match(/\{[^{}]*\}/)

    data = JSON.parse(json_match[0])
    build_strategy_params(data)
  end

  def build_strategy_params(data)
    {
      name: sanitize_name(data["name"]),
      risk_level: sanitize_risk_level(data["risk_level"]),
      max_positions: sanitize_max_positions(data["max_positions"]),
      buy_signal_threshold: sanitize_threshold(data["buy_signal_threshold"], 0.3, 0.7),
      max_position_size: sanitize_threshold(data["max_position_size"], 0.3, 0.7),
      min_cash_reserve: sanitize_threshold(data["min_cash_reserve"], 0.05, 0.4),
      description: sanitize_description(data["description"]),
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

  def fallback_strategy
    detected_risk = @risk_level || detect_risk_level_from_description
    template = TradingStrategy.template_for_risk_level(detected_risk)
    template.attributes.except("id", "created_at", "updated_at").merge(generated_by: :default_template)
  end

  def detect_risk_level_from_description
    text = @description.to_s.downcase

    conservative_keywords = %w[稳健 保守 安全 长期 价值 保护 本金 稳定 分红]
    aggressive_keywords = %w[激进 高收益 快速 进出 机会 风险 高回报 成长]

    conservative_score = conservative_keywords.count { |k| text.include?(k) }
    aggressive_score = aggressive_keywords.count { |k| text.include?(k) }

    return :conservative if conservative_score > aggressive_score
    return :aggressive if aggressive_score > conservative_score

    :balanced
  end
end
