# frozen_string_literal: true

namespace :yahoo do
  desc "Backfill 60 days historical data for all stocks from Yahoo Finance"
  task backfill_historical: :environment do
    Rails.logger.info "[BackfillHistorical] Starting backfill task..."

    # Get all stock type assets
    assets = Asset.where(asset_type: "stock")
    Rails.logger.info "[BackfillHistorical] Found #{assets.count} stocks to process"

    results = { processed: 0, skipped: 0, snapshots_created: 0, failed: 0, errors: [] }

    assets.find_each do |asset|
      process_asset_historical_data(asset, results)
      # Small delay to avoid rate limiting
      sleep 0.5
    end

    Rails.logger.info "[BackfillHistorical] Complete: #{results[:processed]} processed, #{results[:skipped]} skipped, #{results[:snapshots_created]} snapshots created, #{results[:failed]} failed"
    Rails.logger.info "[BackfillHistorical] Errors: #{results[:errors].inspect}"
  end

  desc "Process historical data for a single asset (for debugging)"
  task :backfill_single, [:symbol] => :environment do |_t, args|
    symbol = args[:symbol]
    raise "Symbol is required. Usage: rake yahoo:backfill_single[AAPL]" if symbol.blank?

    Rails.logger.info "[BackfillSingle] Processing #{symbol}..."

    asset = Asset.find_by(symbol: symbol, asset_type: "stock")
    raise "Asset not found: #{symbol}" unless asset

    results = { processed: 0, skipped: 0, snapshots_created: 0, failed: 0, errors: [] }
    process_asset_historical_data(asset, results)

    Rails.logger.info "[BackfillSingle] Complete: #{results.inspect}"
  end
end

# Helper method defined outside namespace for Rake visibility
def process_asset_historical_data(asset, results)
  Rails.logger.info "[BackfillHistorical] Processing #{asset.symbol}..."

  # Get historical data for last 2 months (~60 days)
  historical_data = YahooFinanceService.get_historical_data(
    asset.yahoo_symbol || asset.symbol,
    interval: "1d",
    range: "2mo"
  )

  if historical_data.empty?
    results[:failed] += 1
    results[:errors] << { symbol: asset.symbol, error: "No data returned" }
    Rails.logger.warn "[BackfillHistorical] No data returned for #{asset.symbol}"
    return
  end

  # Store each day's data as a snapshot
  snapshots_created_for_asset = 0
  historical_data.each do |data_point|
    next if data_point[:price].nil? || data_point[:price].zero?

    snapshot_date = data_point[:timestamp].to_date

    # Check if snapshot already exists
    existing = AssetSnapshot.find_by(asset: asset, snapshot_date: snapshot_date)
    next if existing

    AssetSnapshot.create!(
      asset: asset,
      price: data_point[:price],
      volume: data_point[:volume],
      snapshot_date: snapshot_date,
      captured_at: data_point[:timestamp]
    )
    snapshots_created_for_asset += 1
  end

  results[:snapshots_created] += snapshots_created_for_asset
  results[:processed] += 1

  Rails.logger.info "[BackfillHistorical] Created #{snapshots_created_for_asset} snapshots for #{asset.symbol}"
rescue StandardError => e
  results[:failed] += 1
  results[:errors] << { symbol: asset.symbol, error: e.message }
  Rails.logger.error "[BackfillHistorical] Error processing #{asset.symbol}: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")
end
