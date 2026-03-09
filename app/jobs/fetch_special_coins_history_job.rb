# frozen_string_literal: true

# Background job for fetching historical data for special/benchmark coins
# 拉取基准资产的历史数据（如 tether-gold 等必须拉取的 coin）
class FetchSpecialCoinsHistoryJob < ApplicationJob
  queue_as :default

  # 必须拉取的基准资产 coingecko_id 列表
  SPECIAL_COIN_IDS = %w[
    tether-gold
  ].freeze

  def perform
    Rails.logger.info "[FetchSpecialCoinsHistoryJob] Starting at #{Time.current}"

    # 获取必须拉取的基准资产
    assets = Asset.active.crypto.where(coingecko_id: SPECIAL_COIN_IDS)

    if assets.empty?
      Rails.logger.warn "[FetchSpecialCoinsHistoryJob] No special coins found, creating if needed..."
      ensure_special_assets_exist
      assets = Asset.active.crypto.where(coingecko_id: SPECIAL_COIN_IDS)
    end

    if assets.empty?
      Rails.logger.error "[FetchSpecialCoinsHistoryJob] No special coins to fetch"
      return
    end

    Rails.logger.info "[FetchSpecialCoinsHistoryJob] Fetching historical data for #{assets.count} special coins"

    service = CoingeckoService.new
    stats = { success: 0, failed: 0, total_snapshots: 0 }

    assets.each_with_index do |asset, index|
      Rails.logger.info "[FetchSpecialCoinsHistoryJob] [#{index + 1}/#{assets.count}] Processing #{asset.symbol}..."

      begin
        data = service.fetch_market_chart(asset.coingecko_id, days: 5)

        if data["prices"].blank?
          Rails.logger.warn "[FetchSpecialCoinsHistoryJob] No price data for #{asset.symbol}"
          stats[:failed] += 1
          next
        end

        snapshot_count = save_price_snapshots(asset, data["prices"], data["total_volumes"])

        Rails.logger.info "[FetchSpecialCoinsHistoryJob] Saved #{snapshot_count} snapshots for #{asset.symbol}"
        stats[:success] += 1
        stats[:total_snapshots] += snapshot_count

        sleep(1.5) unless index == assets.count - 1

      rescue CoingeckoService::RateLimitError => e
        Rails.logger.warn "[FetchSpecialCoinsHistoryJob] Rate limited, waiting 60s..."
        sleep(60)
        retry
      rescue StandardError => e
        Rails.logger.error "[FetchSpecialCoinsHistoryJob] Failed for #{asset.symbol}: #{e.message}"
        stats[:failed] += 1
      end
    end

    Rails.logger.info "[FetchSpecialCoinsHistoryJob] Completed: #{stats[:success]} success, #{stats[:failed]} failed, #{stats[:total_snapshots]} total snapshots"
  end

  private

  def ensure_special_assets_exist
    special_assets = [
      {
        symbol: 'XAUT',
        name: 'Tether Gold',
        asset_type: 'crypto',
        exchange: 'COINGECKO',
        quote_currency: 'USD',
        coingecko_id: 'tether-gold',
        active: true
      }
    ]

    special_assets.each do |attrs|
      asset = Asset.find_or_initialize_by(symbol: attrs[:symbol], exchange: attrs[:exchange])
      if asset.new_record?
        asset.assign_attributes(attrs)
        asset.save!
        Rails.logger.info "[FetchSpecialCoinsHistoryJob] Created benchmark asset: #{asset.name} (#{asset.symbol})"
      end
    end
  end

  def save_price_snapshots(asset, prices, volumes = [])
    daily_prices = aggregate_data_by_date(prices)
    daily_volumes = aggregate_data_by_date(volumes)

    saved_count = 0

    daily_prices.each do |date, price_data|
      begin
        snapshot = AssetSnapshot.find_or_initialize_by(
          asset: asset,
          snapshot_date: date
        )

        volume_data = daily_volumes[date]

        snapshot.assign_attributes(
          price: price_data[:value],
          volume: volume_data&.dig(:value) || 0,
          captured_at: price_data[:captured_at],
          change_percent: calculate_change_percent(asset, date, price_data[:value])
        )

        snapshot.save!
        saved_count += 1
      rescue StandardError => e
        Rails.logger.warn "[FetchSpecialCoinsHistoryJob] Failed to save snapshot for #{date}: #{e.message}"
      end
    end

    saved_count
  end

  def aggregate_data_by_date(data_points)
    daily_data = {}

    data_points.each do |timestamp_ms, value|
      time = Time.at(timestamp_ms / 1000.0)
      date = time.to_date

      daily_data[date] = {
        value: value,
        captured_at: time
      }
    end

    daily_data
  end

  def calculate_change_percent(asset, date, current_price)
    previous_snapshot = AssetSnapshot.find_by(
      asset: asset,
      snapshot_date: date - 1.day
    )

    return nil unless previous_snapshot&.price&.positive?

    ((current_price - previous_snapshot.price) / previous_snapshot.price * 100).round(4)
  end
end
