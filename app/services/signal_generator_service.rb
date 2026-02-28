# frozen_string_literal: true

# 信号生成服务 - 调用 LLM 生成交易信号并持久化
class SignalGeneratorService
  def initialize(asset, strategy: nil)
    @asset = asset
    @strategy = strategy
  end

  # 生成并保存信号
  def generate_and_save!
    signal_data = generate_signal
    return nil unless signal_data

    create_trading_signal(signal_data)
  end

  # 仅生成信号（不保存）
  def generate_signal
    factor_values = fetch_factor_values
    return nil if factor_values.empty?

    FactorLlmService.generate_signal(@asset, factor_values, @strategy)
  rescue StandardError => e
    Rails.logger.error("SignalGeneratorService Error: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    nil
  end

  private

  def fetch_factor_values
    # 获取该资产最新的因子值
    FactorValue.includes(:factor_definition)
              .where(asset: @asset)
              .joins(:factor_definition)
              .where(factor_definitions: { active: true })
              .order(calculated_at: :desc)
  end

  def create_trading_signal(signal_data)
    factor_values = fetch_factor_values

    # 构建因子快照
    factor_snapshot = build_factor_snapshot(factor_values)

    TradingSignal.create!(
      asset: @asset,
      signal_type: signal_data["signal_type"] || "hold",
      confidence: signal_data["confidence"],
      reasoning: signal_data["reasoning"],
      key_factors: signal_data["key_factors"] || [],
      risk_warning: signal_data["risk_warning"],
      factor_snapshot: factor_snapshot,
      generated_at: Time.current
    )
  end

  def build_factor_snapshot(factor_values)
    factor_values.each_with_object({}) do |fv, hash|
      hash[fv.factor_definition.code] = {
        name: fv.factor_definition.name,
        normalized_value: fv.normalized_value,
        percentile: fv.percentile,
        weight: fv.factor_definition.weight
      }
    end
  end
end
