# frozen_string_literal: true

namespace :asset_data_collection do
  desc "Collect data for all configured assets"
  task collect: :environment do
    puts "Starting asset data collection..."

    start_time = Time.current
    results = AssetDataCollector.collect_all
    end_time = Time.current

    puts "Collection completed in #{(end_time - start_time).round(2)} seconds"
    puts "Success: #{results[:success]} assets"
    puts "Failed: #{results[:failed]} assets"

    if results[:failed] > 0
      puts "\nFailed assets:"
      results[:errors].each do |error|
        puts "  #{error[:symbol]}: #{error[:error]}"
      end
    end
  end

  desc "Collect data for a specific asset"
  task :collect_for, [:symbol] => :environment do |_t, args|
    if args[:symbol].blank?
      puts "Error: Symbol required. Usage: rake 'asset_data_collection:collect_for[symbol]'"
      next
    end

    puts "Collecting data for #{args[:symbol]}..."

    asset = Asset.find_by(symbol: args[:symbol])
    unless asset
      puts "Error: Asset with symbol '#{args[:symbol]}' not found"
      next
    end

    snapshot = AssetDataCollector.collect_for_asset(asset)
    if snapshot
      puts "Success: Collected data for #{args[:symbol]} - Price: $#{snapshot.price}"
    else
      puts "Error: Failed to collect data for #{args[:symbol]}"
    end
  end

  desc "Collect historical data for assets"
  task collect_historical: :environment do
    puts "Collecting historical data for all assets..."

    interval = ENV.fetch("INTERVAL", "1h")
    range = ENV.fetch("RANGE", "5d")

    start_time = Time.current
    total_snapshots = 0
    failed_assets = []

    Asset.find_each do |asset|
      begin
        count = AssetDataCollector.collect_historical_for_asset(asset, interval:, range:)
        total_snapshots += count
        puts "Collected #{count} historical snapshots for #{asset.symbol}" if count > 0
      rescue StandardError => e
        failed_assets << { symbol: asset.symbol, error: e.message }
        puts "Error collecting historical data for #{asset.symbol}: #{e.message}"
      end
    end

    end_time = Time.current
    puts "\nHistorical collection completed in #{(end_time - start_time).round(2)} seconds"
    puts "Total snapshots created: #{total_snapshots}"

    unless failed_assets.empty?
      puts "\nFailed assets:"
      failed_assets.each { |f| puts "  #{f[:symbol]}: #{f[:error]}" }
    end
  end

  desc "Check asset data collection health"
  task health_check: :environment do
    puts "Checking asset data collection health..."

    health = AssetDataCollector.health_status

    puts "\nHealth Summary:"
    puts "Total assets: #{health[:total_assets]}"
    puts "Assets with recent data: #{health[:assets_with_recent_data]}"
    puts "Assets needing update: #{health[:assets_needing_update]}"
    puts "Overall status: #{health[:healthy] ? 'HEALTHY' : 'UNHEALTHY'}"
    puts "Last collection time: #{health[:last_collection_time] || 'Never'}"

    if health[:stale_asset_symbols].any?
      puts "\nStale assets (no data in 4 hours):"
      health[:stale_asset_symbols].each { |symbol| puts "  - #{symbol}" }
    end
  end

  desc "Seed test assets if they don't exist"
  task seed_test_assets: :environment do
    puts "Seeding test assets..."

    assets = [
      { symbol: "BTC", name: "Bitcoin", asset_type: "crypto" },
      { symbol: "ETH", name: "Ethereum", asset_type: "crypto" },
      { symbol: "AAPL", name: "Apple Inc.", asset_type: "stock" },
      { symbol: "NVDA", name: "NVIDIA Corporation", asset_type: "stock" },
      { symbol: "GLD", name: "SPDR Gold Shares", asset_type: "commodity" }
    ]

    assets.each do |asset_data|
      existing = Asset.find_by(symbol: asset_data[:symbol])
      if existing
        puts "Asset #{asset_data[:symbol]} already exists"
      else
        Asset.create!(asset_data)
        puts "Created asset #{asset_data[:symbol]}"
      end
    end

    puts "Test assets seeding completed"
  end

  desc "Collect data using Swarm SDK multi-agent system"
  task swarm_collect: :environment do
    puts "Starting asset data collection via Swarm..."

    start_time = Time.current

    # Check if SwarmSDK is available
    begin
      require "swarm_sdk"
      puts "SwarmSDK loaded successfully"
    rescue LoadError
      puts "Error: SwarmSDK not available. Add 'gem \"swarm_sdk\", github: \"parruda/swarm\"' to Gemfile and run bundle install"
      next
    end

    # Run swarm collection
    result = SwarmDataCollectorService.collect_data

    end_time = Time.current

    if result[:success]
      puts "Swarm collection completed in #{(end_time - start_time).round(2)} seconds"
      puts "Result: #{result[:result]}"
    else
      puts "Swarm collection failed: #{result[:error]}"
    end
  end

  desc "Test Swarm SDK with a single asset"
  task :swarm_test, [:symbol] => :environment do |_t, args|
    symbol = args[:symbol] || "AAPL"

    puts "Testing Swarm SDK with #{symbol}..."

    asset = Asset.find_by(symbol: symbol)
    unless asset
      puts "Error: Asset with symbol '#{symbol}' not found"
      next
    end

    start_time = Time.current

    result = SwarmDataCollectorService.collect_for_asset(symbol, asset.asset_type)

    end_time = Time.current

    if result[:success]
      puts "Swarm test completed in #{(end_time - start_time).round(2)} seconds"
      puts "Result:"
      puts result[:result]
    else
      puts "Swarm test failed: #{result[:error]}"
    end
  end

  desc "Enqueue asset data collection job (one-time)"
  task enqueue: :environment do
    puts "Enqueuing asset data collection job..."

    job = AssetDataCollectionJob.perform_later

    puts "Job enqueued with ID: #{job.job_id}"
    puts "Job will execute according to sidekiq_schedule.yml"
  end

  desc "Run asset data collection job immediately (synchronous)"
  task run_now: :environment do
    puts "Running asset data collection job immediately..."

    start_time = Time.current

    AssetDataCollectionJob.perform_now

    end_time = Time.current

    puts "Job completed in #{(end_time - start_time).round(2)} seconds"
  end

  desc "Analyze asset using AI"
  task :analyze, [:symbol] => :environment do |_t, args|
    symbol = args[:symbol] || "BTC"

    puts "Analyzing #{symbol} using AI..."

    asset = Asset.find_by(symbol: symbol)
    unless asset
      puts "Error: Asset with symbol '#{symbol}' not found"
      next
    end

    hours = (ENV["HOURS"] || 48).to_i
    use_swarm = ENV["USE_SWARM"] != "false"

    puts "Analysis type: #{use_swarm ? 'Full Swarm' : 'Quick Signal'}"
    puts "Hours of data: #{hours}"

    start_time = Time.current

    if use_swarm
      result = SwarmAssetAnalyzerService.analyze(asset)
    else
      result = AIDataAnalyzerService.generate_trading_signals(asset)
    end

    end_time = Time.current

    if result[:success] || !result[:error]
      puts "Analysis completed in #{(end_time - start_time).round(2)} seconds"
      puts "Trend Direction: #{result[:trend_direction]}"
      puts "Trading Signal: #{result[:trading_signal]}"
      puts "Support Level: $#{result[:support_level]}"
      puts "Resistance Level: $#{result[:resistance_level]}"
      puts "Confidence: #{result[:confidence]}"
    else
      puts "Analysis failed: #{result[:error]}"
    end
  end

  desc "Analyze all assets using AI"
  task analyze_all: :environment do
    puts "Analyzing all assets using AI..."

    assets = Asset.all
    results = {}

    assets.each do |asset|
      begin
        result = SwarmAssetAnalyzerService.analyze(asset)
        results[asset.symbol] = result[:success] ? result : { error: result[:error] }

        symbol_status = result[:success] ? "✓" : "✗"
        puts "  #{symbol_status} #{asset.symbol}: #{result[:trend_direction] || 'N/A'}"
      rescue StandardError => e
        results[asset.symbol] = { error: e.message }
        puts "  ✗ #{asset.symbol}: #{e.message}"
      end
    end

    puts "\nAnalysis complete for #{results.size} assets"
    puts "Success: #{results.values.count { |r| r[:success] || !r[:error] }}"
    puts "Failed: #{results.values.count { |r| r[:error] }}"
  end

  desc "Generate batch AI analysis (quick signals for all assets)"
  task quick_signals: :environment do
    puts "Generating quick trading signals for all assets..."

    results = SwarmAssetAnalyzerService.analyze_batch(Asset.all)

    puts "\nQuick Signals Generated:"
    results[:data].each do |symbol, result|
      next if result[:error]

      puts "  #{symbol}:"
      puts "    Signal: #{result[:trading_signal]}"
      puts "    Confidence: #{result[:confidence]}"
      puts "    Price: $#{result[:current_price]}"
    end
  end
end

