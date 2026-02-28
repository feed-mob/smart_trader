# frozen_string_literal: true

# LLM 服务 - 复用 AiChatService
class FactorLlmService
  SYSTEM_PROMPT = <<~PROMPT
    你是 SmartTrader 量化交易系统的 AI 分析师。

    你的职责：
    - 分析交易因子数据
    - 生成交易信号和投资建议
    - 识别风险和异常
    - 撰写专业分析报告

    你的回答应该：
    - 专业、准确、有依据
    - 简洁明了，避免冗余
    - 考虑风险因素
    - 基于数据而非猜测
  PROMPT

  # 普通文本回答
  def self.ask(prompt, instructions: nil)
    service = AiChatService.new(
      instructions: instructions || SYSTEM_PROMPT,
      temperature: 0.3,
      max_tokens: 2000
    )
    service.ask(prompt)
  end

  # JSON 格式回答
  def self.ask_json(prompt, instructions: nil)
    json_instructions = <<~PROMPT
      #{instructions || SYSTEM_PROMPT}

      重要：你必须返回有效的 JSON 格式，不要包含 markdown 代码块标记，不要包含其他解释文字。
    PROMPT

    service = AiChatService.new(
      instructions: json_instructions,
      temperature: 0.1,
      max_tokens: 2000
    )

    response = service.ask(prompt)
    parse_json(response)
  end

  # 因子解读
  def self.interpret_factors(asset, factor_values)
    prompt = build_interpretation_prompt(asset, factor_values)
    ask(prompt)
  end

  # 生成交易信号
  def self.generate_signal(asset, factor_values, strategy = nil)
    prompt = build_signal_prompt(asset, factor_values, strategy)
    ask_json(prompt)
  end

  private

  def self.parse_json(response)
    return nil if response.blank?

    cleaned = response.strip
                       .gsub(/^```json\s*/i, '')
                       .gsub(/^```\s*/i, '')
                       .gsub(/\s*```$/, '')

    JSON.parse(cleaned)
  rescue JSON::ParserError => e
    Rails.logger.error("FactorLlmService JSON Parse Error: #{e.message}")
    Rails.logger.error("Response was: #{response[0..500]}")
    nil
  end

  def self.build_interpretation_prompt(asset, factor_values)
    <<~PROMPT
      你是一位专业的量化分析师。请分析以下资产的因子数据，给出简洁的解读。

      资产信息：
      - 名称：#{asset.name} (#{asset.symbol})

      因子数据：
      #{format_factor_values(factor_values)}

      请回答：
      1. 这个资产目前的主要特征是什么？（用1-2句话概括）
      2. 哪些因子表现突出？意味着什么？
      3. 综合来看，这个资产处于什么状态？（强势/弱势/震荡）

      请用简洁专业的语言回答，不要超过100字。
    PROMPT
  end

  def self.build_signal_prompt(asset, factor_values, strategy)
    strategy_info = strategy ? build_strategy_info(strategy) : "使用默认策略参数"

    <<~PROMPT
      你是一位专业的交易信号分析师。根据以下因子数据，生成交易信号。

      ## 策略信息
      #{strategy_info}

      ## 资产信息
      - 资产：#{asset.name} (#{asset.symbol})

      ## 因子数据
      #{format_factor_values(factor_values)}

      ## 任务
      根据因子数据生成交易信号。

      返回 JSON 格式：
      {
        "signal_type": "buy|sell|hold",
        "confidence": 0.0-1.0,
        "reasoning": "简要说明信号原因（50字以内）",
        "key_factors": ["主要驱动因子1", "主要驱动因子2"],
        "risk_warning": "风险提示（如有，可选）"
      }

      注意：
      - 综合考虑所有因子，不要只看单一因子
      - 因子之间可能存在矛盾，需要权衡判断
      - 考虑因子的绝对值和相对变化
    PROMPT
  end

  def self.build_strategy_info(strategy)
    <<~INFO
      - 策略名称：#{strategy.name}
      - 风险偏好：#{strategy.risk_level}
      - 买入信号阈值：#{strategy.buy_signal_threshold}
      - 最大仓位：#{(strategy.max_position_size * 100).round(0)}%
    INFO
  end

  def self.format_factor_values(factor_values)
    return "暂无因子数据" if factor_values.empty?

    factor_values.map do |fv|
      factor = fv.factor_definition
      "- #{factor.name}: 得分 #{fv.normalized_value.round(2)} (百分位: #{fv.percentile || 'N/A'}%)"
    end.join("\n")
  end
end
