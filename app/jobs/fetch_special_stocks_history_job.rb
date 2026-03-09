# frozen_string_literal: true

# Background job for fetching historical data for special/benchmark stocks and indexes from Yahoo Finance
# 拉取基准股票/指数的历史数据（如 NASDAQ 等）
class FetchSpecialStocksHistoryJob < ApplicationJob
  queue_as :default

  # Yahoo Finance 指数符号列表 (market_cap_rank = 0 表示基准指数)
  YAHOO_INDEX_SYMBOLS = [
    { yahoo_symbol: "^IXIC", symbol: "IXIC", name: "NASDAQ Composite", exchange: "NASDAQ", market_cap_rank: 0 }
  ].freeze

  def perform
    Rails.logger.info "[FetchSpecialStocksHistoryJob] Starting at #{Time.current}"

    stats = { success: 0, failed: 0, total_snapshots: 0 }

    YAHOO_INDEX_SYMBOLS.each_with_index do |symbol_info, index|
      Rails.logger.info "[FetchSpecialStocksHistoryJob] [#{index + 1}/#{YAHOO_INDEX_SYMBOLS.count}] Processing #{symbol_info[:yahoo_symbol]}..."

      begin
        asset = ensure_asset_exists(symbol_info)
        snapshot_count = fetch_and_save_yahoo_historical(asset)

        Rails.logger.info "[FetchSpecialStocksHistoryJob] Saved #{snapshot_count} snapshots for #{symbol_info[:yahoo_symbol]}"
        stats[:success] += 1
        stats[:total_snapshots] += snapshot_count

        sleep(0.5) unless index == YAHOO_INDEX_SYMBOLS.count - 1

      rescue StandardError => e
        Rails.logger.error "[FetchSpecialStocksHistoryJob] Failed for #{symbol_info[:yahoo_symbol]}: #{e.message}"
        stats[:failed] += 1
      end
    end

    Rails.logger.info "[FetchSpecialStocksHistoryJob] Completed: #{stats[:success]} success, #{stats[:failed]} failed, #{stats[:total_snapshots]} total snapshots"
  end

  private

  def ensure_asset_exists(symbol_info)
    asset = Asset.find_or_initialize_by(yahoo_symbol: symbol_info[:yahoo_symbol])
    if asset.new_record?
      asset.assign_attributes(
        symbol: symbol_info[:symbol],
        name: symbol_info[:name],
        asset_type: "stock",
        exchange: symbol_info[:exchange],
        quote_currency: "USD",
        market_cap_rank: symbol_info[:market_cap_rank],
        active: true
      )
      asset.save!
      Rails.logger.info "[FetchSpecialStocksHistoryJob] Created asset: #{asset.name} (#{asset.yahoo_symbol})"
    end
    asset
  end

  def fetch_and_save_yahoo_historical(asset)
    historical_data = YahooFinanceService.get_historical_data(
      asset.yahoo_symbol,
      interval: "1d",
      range: "2mo"
    )

    return 0 if historical_data.empty?

    snapshots_created = 0
    snapshots_updated = 0
    previous_price = nil

    historical_data.sort_by { |data_point| data_point[:timestamp] }.each do |data_point|
      next if data_point[:price].nil? || data_point[:price].zero?

      snapshot_date = data_point[:timestamp].to_date

      # Calculate change_percent based on previous day's close price
      change_percent = if previous_price && previous_price.nonzero?
        ((data_point[:price] - previous_price) / previous_price * 100).round(4)
      end

      # Create or update snapshot
      snapshot = AssetSnapshot.find_or_initialize_by(asset: asset, snapshot_date: snapshot_date)
      is_new_record = snapshot.new_record?

      snapshot.assign_attributes(
        price: data_point[:price],
        change_percent: change_percent,
        volume: data_point[:volume],
        captured_at: data_point[:timestamp]
      )
      snapshot.save!

      is_new_record ? snapshots_created += 1 : snapshots_updated += 1
      previous_price = data_point[:price]
    end

    Rails.logger.info "[FetchSpecialStocksHistoryJob] #{asset.yahoo_symbol}: created #{snapshots_created}, updated #{snapshots_updated}"
    snapshots_created + snapshots_updated
  end
end
