# frozen_string_literal: true

# 定时任务 - 为所有资产生成交易信号
class GenerateSignalsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("GenerateSignalsJob started at #{Time.current}")

    assets = Asset.all
    results = { success: 0, failed: 0, skipped: 0 }

    assets.find_each do |asset|
      result = generate_signal_for_asset(asset)
      results[result] += 1
    end

    Rails.logger.info("GenerateSignalsJob completed: #{results}")
    results
  end

  private

  def generate_signal_for_asset(asset)
    # 检查是否有因子数据
    return :skipped unless has_factor_values?(asset)

    service = SignalGeneratorService.new(asset)
    signal = service.generate_and_save!

    signal.present? ? :success : :failed
  rescue StandardError => e
    Rails.logger.error("GenerateSignalsJob failed for #{asset.symbol}: #{e.message}")
    :failed
  end

  def has_factor_values?(asset)
    FactorValue.where(asset: asset).exists?
  end
end
