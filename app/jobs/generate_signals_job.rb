# frozen_string_literal: true

# 定时任务 - 为 market_cap_rank <= 50 的资产生成交易信号
class GenerateSignalsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("GenerateSignalsJob started at #{Time.current}")

    # 只处理 market_cap_rank <= 50 的活跃资产
    assets = Asset.active.where("market_cap_rank <= ?", 50)
    results = { success: 0, failed: 0, skipped: 0 }

    assets.find_each do |asset|
      Rails.logger.info("GenerateSignalsJob: Processing asset #{asset.symbol} (rank: #{asset.market_cap_rank})")
      result = generate_signal_for_asset(asset)
      results[result] += 1
    end

    Rails.logger.info("GenerateSignalsJob completed: #{results}")
    results
  end

  private

  def generate_signal_for_asset(asset)
    # 检查是否有因子数据
    unless has_factor_values?(asset)
      Rails.logger.info("GenerateSignalsJob: Skipped #{asset.symbol} - no factor values")
      return :skipped
    end

    service = SignalGeneratorService.new(asset)
    signal = service.generate_and_save!

    if signal.present?
      Rails.logger.info("GenerateSignalsJob: Generated signal for #{asset.symbol}")
      :success
    else
      Rails.logger.warn("GenerateSignalsJob: Failed to generate signal for #{asset.symbol}")
      :failed
    end
  rescue StandardError => e
    Rails.logger.error("GenerateSignalsJob failed for #{asset.symbol}: #{e.message}")
    :failed
  end

  def has_factor_values?(asset)
    FactorValue.where(asset: asset).exists?
  end
end
