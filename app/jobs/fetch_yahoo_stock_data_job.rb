# frozen_string_literal: true

# Job to fetch and save top 100 stocks by market cap from Yahoo Finance
# Can be scheduled as a recurring task to keep assets table updated
class FetchYahooStockDataJob < ApplicationJob
  queue_as :yahoo_finance

  retry_on Net::OpenTimeout, wait: :exponentially_longer, attempts: 3
  retry_on HTTParty::Error, wait: :exponentially_longer, attempts: 3

  def perform(scr_id: "largest_market_cap", count: 100)
    Rails.logger.info "[FetchYahooStockDataJob] Starting to fetch top #{count} stocks..."

    stocks_data = YahooFinanceService.get_screener_data(scr_id:, count:)
    Rails.logger.info "[FetchYahooStockDataJob] Fetched #{stocks_data.size} stocks from Yahoo"

    results = { created: 0, updated: 0, failed: 0, errors: [] }

    stocks_data.each do |stock_data|
      process_stock(stock_data, results)
    end

    Rails.logger.info "[FetchYahooStockDataJob] Complete: #{results[:created]} created, #{results[:updated]} updated, #{results[:failed]} failed"
    results
  end

  private

  def process_stock(stock_data, results)
    # Find existing asset or create new one
    asset = Asset.find_or_initialize_by(
      symbol: stock_data[:symbol],
      quote_currency: "USD"
    )

    # Set/update asset attributes
    asset.name = stock_data[:name]
    asset.yahoo_symbol = stock_data[:symbol]
    asset.exchange = map_exchange(stock_data[:exchange])
    asset.asset_type = "stock"
    asset.active = true

    # Update price data
    asset.current_price = stock_data[:price]
    asset.last_updated = stock_data[:timestamp]

    if asset.save
      # Create snapshot
      create_snapshot(asset, stock_data)

      if asset.previously_new_record?
        results[:created] += 1
        Rails.logger.info "[FetchYahooStockDataJob] Created: #{asset.symbol} - #{asset.name}"
      else
        results[:updated] += 1
        Rails.logger.info "[FetchYahooStockDataJob] Updated: #{asset.symbol}"
      end
    else
      results[:failed] += 1
      error_msg = asset.errors.full_messages.join(", ")
      results[:errors] << { symbol: stock_data[:symbol], error: error_msg }
      Rails.logger.error "[FetchYahooStockDataJob] Failed to save #{stock_data[:symbol]}: #{error_msg}"
    end
  rescue StandardError => e
    results[:failed] += 1
    results[:errors] << { symbol: stock_data[:symbol], error: e.message }
    Rails.logger.error "[FetchYahooStockDataJob] Error processing #{stock_data[:symbol]}: #{e.message}"
  end

  def create_snapshot(asset, stock_data)
    AssetSnapshot.find_or_create_by(
      asset: asset,
      snapshot_date: stock_data[:timestamp].to_date
    ) do |snapshot|
      snapshot.price = stock_data[:price]
      snapshot.change_percent = stock_data[:change_percent]
      snapshot.volume = stock_data[:volume]
      snapshot.captured_at = stock_data[:timestamp]
    end
  end

  # Map Yahoo exchange codes to readable names
  def map_exchange(yahoo_exchange)
    exchange_map = {
      "NMS" => "NASDAQ",
      "NYS" => "NYSE",
      "ASE" => "AMEX",
      "PCX" => "NYSE",
      "PNK" => "OTC",
      "NGM" => "NASDAQ",
      "OQN" => "NASDAQ"
    }
    exchange_map[yahoo_exchange] || yahoo_exchange || "UNKNOWN"
  end
end
