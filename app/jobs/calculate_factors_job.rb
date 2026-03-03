# frozen_string_literal: true

class CalculateFactorsJob < ApplicationJob
  queue_as :default

  def perform
    return unless defined?(Asset) && Asset.table_exists?

    factors = FactorDefinition.active.ordered
    assets = Asset.where(active: true)

    if factors.empty? || assets.empty?
      Rails.logger.info("CalculateFactorsJob: No active factors or assets to process")
      return
    end

    Rails.logger.info("CalculateFactorsJob: Calculating #{factors.count} factors for #{assets.count} assets")

    assets.find_each do |asset|
      factors.find_each do |factor|
        calculate_and_save_factor(asset, factor)
      end
    end

    # 计算百分位
    calculate_percentiles(factors)

    Rails.logger.info("CalculateFactorsJob: Completed")
  end

  private

  def calculate_and_save_factor(asset, factor)
    calculator = FactorCalculatorService.new(factor, asset)
    result = calculator.calculate

    return if result[:error].present?

    # 检查 FactorValue 模型是否存在
    return unless defined?(FactorValue) && FactorValue.table_exists?

    FactorValue.create!(
      asset: asset,
      factor_definition: factor,
      raw_value: result[:raw_value],
      normalized_value: result[:normalized_value],
      calculated_at: Time.current
    )
  rescue => e
    Rails.logger.error("CalculateFactorsJob error for #{factor.code}/#{asset.symbol}: #{e.message}")
  end

  def calculate_percentiles(factors)
    return unless defined?(FactorValue) && FactorValue.table_exists?

    factors.find_each do |factor|
      values = FactorValue.where(factor_definition: factor)
                          .where('calculated_at > ?', 1.hour.ago)
                          .where.not(raw_value: nil)
                          .order(raw_value: :asc)

      next if values.count < 2

      total = values.count
      values.each_with_index do |factor_value, index|
        percentile = ((index + 1).to_f / total * 100).round(2)
        factor_value.update_column(:percentile, percentile)
      end
    end
  end
end
