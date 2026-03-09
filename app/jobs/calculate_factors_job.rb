# frozen_string_literal: true

class CalculateFactorsJob < ApplicationJob
  queue_as :default

  # @param asset_symbol [String, nil] Optional asset symbol to calculate factors for (e.g., "ETH", "BTC")
  #   If nil, calculates for all active assets
  def perform(asset_symbol = nil)
    factors = FactorDefinition.active.ordered

    assets = if asset_symbol.present?
      Asset.where(active: true).where("symbol ILIKE ?", asset_symbol.upcase)
    else
      Asset.where(active: true)
    end

    if factors.empty? || assets.empty?
      Rails.logger.info("CalculateFactorsJob: No active factors or assets to process (symbol: #{asset_symbol})")
      return
    end

    log_message = if asset_symbol.present?
      "CalculateFactorsJob: Calculating #{factors.count} factors for #{assets.count} asset(s) matching '#{asset_symbol}'"
    else
      "CalculateFactorsJob: Calculating #{factors.count} factors for #{assets.count} assets"
    end
    Rails.logger.info(log_message)

    assets.find_each do |asset|
      factors.each do |factor|
        calculate_and_save_factor(asset, factor)
      end
    end

    # 计算百分位（基于所有资产）
    calculate_percentiles(factors)

    Rails.logger.info("CalculateFactorsJob: Completed")
  end

  private

  def calculate_and_save_factor(asset, factor)
    calculator = FactorCalculatorService.new(factor, asset)
    result = calculator.calculate

    return if result[:error].present?

    # 一天只保存一条记录，使用当天开始时间作为 calculated_at
    today = Date.current.beginning_of_day

    factor_value = FactorValue.find_or_initialize_by(
      asset: asset,
      factor_definition: factor,
      calculated_at: today
    )

    factor_value.assign_attributes(
      raw_value: result[:raw_value],
      normalized_value: result[:normalized_value]
    )
    factor_value.save!
  rescue => e
    Rails.logger.error("CalculateFactorsJob error for #{factor.code}/#{asset.symbol}: #{e.message}")
  end

  def calculate_percentiles(factors)
    # 百分位需要基于所有资产、同一天的数据计算
    today = Date.current.beginning_of_day

    factors.each do |factor|
      # 获取今天所有资产的因子值
      values = FactorValue.where(factor_definition: factor)
                          .where(calculated_at: today)
                          .where.not(normalized_value: nil)
                          .order(normalized_value: :asc)

      next if values.count < 2

      total = values.count
      values.each_with_index do |factor_value, index|
        percentile = ((index + 1).to_f / total * 100).round(2)
        factor_value.update_column(:percentile, percentile)
      end
    end
  end
end
