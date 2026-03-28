# frozen_string_literal: true

class ApplyTraderReflectionAdjustmentService
  PARAMETER_RULES = {
    "max_positions" => { step: 1, min: 2, max: 10, integer: true },
    "buy_signal_threshold" => { step: 0.05, min: 0.3, max: 0.7, integer: false },
    "max_position_size" => { step: 0.05, min: 0.3, max: 0.7, integer: false },
    "min_cash_reserve" => { step: 0.05, min: 0.05, max: 0.4, integer: false }
  }.freeze

  def self.preview_value(parameter, before_value, direction)
    rule = PARAMETER_RULES[parameter.to_s]
    raise ArgumentError, "不支持的策略参数" unless rule

    adjusted_value(before_value, direction, rule)
  end

  def initialize(trader_reflection, parameter:)
    @trader_reflection = trader_reflection
    @parameter = parameter.to_s
  end

  def call
    adjustment = suggested_adjustment
    raise ArgumentError, "未找到对应的参数调整建议" unless adjustment
    raise ArgumentError, "该参数建议已经应用过了" if applied_log.present?

    strategy = @trader_reflection.trading_strategy || @trader_reflection.trader.default_strategy
    raise ArgumentError, "当前 trader 没有可调整的策略" unless strategy

    rule = PARAMETER_RULES[@parameter]
    raise ArgumentError, "不支持的策略参数" unless rule

    before_value = strategy.public_send(@parameter)
    after_value = self.class.preview_value(@parameter, before_value, adjustment["direction"])

    TradingStrategy.transaction do
      strategy.update!(
        @parameter => after_value,
        generated_by: :manual
      )

      StrategyAdjustmentLog.create!(
        trader_reflection: @trader_reflection,
        trading_strategy: strategy,
        parameter: @parameter,
        direction: adjustment["direction"],
        reason: adjustment["reason"],
        before_value: before_value,
        after_value: after_value,
        applied_at: Time.current
      )
    end

    strategy
  end

  private

  def suggested_adjustment
    Array(@trader_reflection.suggested_adjustments).find do |adjustment|
      adjustment["parameter"].to_s == @parameter
    end
  end

  def applied_log
    @applied_log ||= @trader_reflection.strategy_adjustment_logs.find_by(parameter: @parameter)
  end

  def self.adjusted_value(before_value, direction, rule)
    raw_value = before_value.to_d

    updated_value = case direction.to_s
                    when "increase"
                      raw_value + BigDecimal(rule[:step].to_s)
                    when "decrease"
                      raw_value - BigDecimal(rule[:step].to_s)
                    else
                      raw_value
                    end

    clamped_value = [[updated_value, BigDecimal(rule[:min].to_s)].max, BigDecimal(rule[:max].to_s)].min
    rule[:integer] ? clamped_value.to_i : clamped_value.round(2).to_f
  end
end
