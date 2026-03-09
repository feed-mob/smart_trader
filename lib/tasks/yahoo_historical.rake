# frozen_string_literal: true

namespace :yahoo do
  desc "Backfill 60 days historical data for all stocks from Yahoo Finance"
  task backfill_historical: :environment do
    puts "[BackfillHistorical] Starting backfill task..."

    # Get all stock type assets
    assets = Asset.where(asset_type: "stock")
    puts "[BackfillHistorical] Found #{assets.count} stocks to process"

    results = { processed: 0, snapshots_created: 0, snapshots_updated: 0, failed: 0, errors: [] }

    assets.find_each do |asset|
      process_asset_historical_data(asset, results)
      # Small delay to avoid rate limiting
      sleep 0.5
    end

    puts "[BackfillHistorical] Complete: #{results[:processed]} processed, #{results[:snapshots_created]} created, #{results[:snapshots_updated]} updated, #{results[:failed]} failed"
    puts "[BackfillHistorical] Errors: #{results[:errors].inspect}"
  end

  desc "Process historical data for a single asset (for debugging)"
  task :backfill_single, [:symbol] => :environment do |_t, args|
    symbol = args[:symbol]
    raise "Symbol is required. Usage: rake yahoo:backfill_single[AAPL]" if symbol.blank?

    puts "[BackfillSingle] Processing #{symbol}..."

    asset = Asset.find_by(symbol: symbol, asset_type: "stock")
    raise "Asset not found: #{symbol}" unless asset

    results = { processed: 0, snapshots_created: 0, snapshots_updated: 0, failed: 0, errors: [] }
    process_asset_historical_data(asset, results)

    puts "[BackfillSingle] Complete: #{results.inspect}"
  end
end

# Helper method defined outside namespace for Rake visibility
def process_asset_historical_data(asset, results)
  puts "[BackfillHistorical] Processing #{asset.symbol}..."

  # Check if yesterday has data
  yesterday = Date.current - 1.day
  yesterday_snapshot = AssetSnapshot.find_by(asset: asset, snapshot_date: yesterday)

  # If no data yesterday, only process market_cap_rank top 50
  if yesterday_snapshot.blank?
    if asset.market_cap_rank.nil? || asset.market_cap_rank > 50
      puts "[BackfillHistorical] Skipping #{asset.symbol} - no data yesterday and market_cap_rank > 50"
      return
    end
  end

  # Get historical data for last 2 months (~60 days)
  historical_data = YahooFinanceService.get_historical_data(
    asset.yahoo_symbol || asset.symbol,
    interval: "1d",
    range: "2mo"
  )

  if historical_data.empty?
    results[:failed] += 1
    results[:errors] << { symbol: asset.symbol, error: "No data returned" }
    puts "[BackfillHistorical] No data returned for #{asset.symbol}"
    return
  end

  # Store each day's data as a snapshot (create or update)
  snapshots_created_for_asset = 0
  snapshots_updated_for_asset = 0
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

    if is_new_record
      snapshots_created_for_asset += 1
    else
      snapshots_updated_for_asset += 1
    end

    previous_price = data_point[:price]
  end

  results[:snapshots_created] += snapshots_created_for_asset
  results[:snapshots_updated] ||= 0
  results[:snapshots_updated] += snapshots_updated_for_asset
  results[:processed] += 1

  puts "[BackfillHistorical] Created #{snapshots_created_for_asset}, updated #{snapshots_updated_for_asset} snapshots for #{asset.symbol}"
rescue StandardError => e
  results[:failed] += 1
  results[:errors] << { symbol: asset.symbol, error: e.message }
  puts "[BackfillHistorical] Error processing #{asset.symbol}: #{e.message}"
  puts e.backtrace.join("\n")
end
