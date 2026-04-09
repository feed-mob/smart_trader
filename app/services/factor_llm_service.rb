# frozen_string_literal: true

# LLM Service - reuse AiChatService
class FactorLlmService
  SYSTEM_PROMPT = <<~PROMPT
    You are the AI analyst for SmartTrader quantitative trading system.

    Your responsibilities:
    - Analyze trading factor data
    - Generate trading signals and investment recommendations
    - Identify risks and anomalies
    - Write professional analysis reports

    Your responses should be:
    - Professional, accurate, and well-founded
    - Concise and clear, avoid redundancy
    - Consider risk factors
    - Based on data, not speculation
    - Generate English version
  PROMPT

  # Plain text response
  def self.ask(prompt, instructions: nil)
    service = AiChatService.new(
      instructions: instructions || SYSTEM_PROMPT,
      temperature: 0.3,
      max_tokens: 2000
    )
    service.ask(prompt)
  end

  # JSON format response
  def self.ask_json(prompt, instructions: nil)
    json_instructions = <<~PROMPT
      #{instructions || SYSTEM_PROMPT}

      IMPORTANT: You must return valid JSON format, do not include markdown code block markers, do not include other explanatory text.
    PROMPT

    service = AiChatService.new(
      instructions: json_instructions,
      temperature: 0.1,
      max_tokens: 2000
    )

    response = service.ask(prompt)
    parse_json(response)
  end

  # Factor interpretation
  def self.interpret_factors(asset, factor_values)
    prompt = build_interpretation_prompt(asset, factor_values)
    ask(prompt)
  end

  # Generate trading signal
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
      You are a professional quantitative analyst. Please analyze the following asset's factor data and provide a concise interpretation.

      Asset Information:
      - Name: #{asset.name} (#{asset.symbol})

      Factor Data:
      #{format_factor_values(factor_values)}

      Please answer:
      1. What are the main characteristics of this asset currently? (Summarize in 1-2 sentences)
      2. Which factors stand out? What does this mean?
      3. Overall, what state is this asset in? (Strong/Weak/Volatile)

      Please respond in concise professional language, no more than 100 words.
    PROMPT
  end

  def self.build_signal_prompt(asset, factor_values, strategy)
    strategy_info = strategy ? build_strategy_info(strategy) : "Using default strategy parameters"

    <<~PROMPT
      You are a professional trading signal analyst. Generate trading signals based on the following factor data.

      ## Strategy Information
      #{strategy_info}

      ## Asset Information
      - Asset: #{asset.name} (#{asset.symbol})

      ## Factor Data
      #{format_factor_values(factor_values)}

      ## Task
      Generate a trading signal based on factor data.

      Return JSON format:
      {
        "signal_type": "buy|sell|hold",
        "confidence": 0.0-1.0,
        "reasoning": "Brief explanation of signal reason (within 50 words)",
        "key_factors": ["Key driving factor 1", "Key driving factor 2"],
        "risk_warning": "Risk warning (if any, optional)"
      }

      Notes:
      - Consider all factors comprehensively, not just a single factor
      - Factors may conflict, need to weigh and judge
      - Consider both absolute and relative changes of factors
    PROMPT
  end

  def self.build_strategy_info(strategy)
    <<~INFO
      - Strategy Name: #{strategy.name}
      - Risk Level: #{strategy.risk_level}
      - Buy Signal Threshold: #{strategy.buy_signal_threshold}
      - Max Position Size: #{(strategy.max_position_size * 100).round(0)}%
    INFO
  end

  def self.format_factor_values(factor_values)
    return "No factor data available" if factor_values.empty?

    factor_values.map do |fv|
      factor = fv.factor_definition
      "- #{factor.name}: Score #{fv.normalized_value.round(2)} (Percentile: #{fv.percentile || 'N/A'}%)"
    end.join("\n")
  end
end
