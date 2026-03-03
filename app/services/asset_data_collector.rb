# frozen_string_literal: true

# Asset Data Collector - Main service for collecting asset data from multiple sources
# This service coordinates data collection from Yahoo Finance and TradingView MCP
class AssetDataCollector
  # Collect and store data for all assets
  # @return [Hash] Collection results summary
  def self.collect_all
    results = { success: 0, failed: 0, errors: [] }

    Asset.find_each do |asset|
      begin
        collect_for_asset(asset)
        results[:success] += 1
      rescue StandardError => e
        results[:failed] += 1
        results[:errors] << { symbol: asset.symbol, error: e.message }
        Rails.logger.error "[AssetDataCollector] Failed to collect data for #{asset.symbol}: #{e.message}"
      end
    end

    Rails.logger.info "[AssetDataCollector] Collection complete: #{results[:success]} success, #{results[:failed]} failed"
    results
  end

  # Collect and store data for a single asset
  # @param asset [Asset] The asset to collect data for
  # @param use_swarm [Boolean] Whether to use Swarm SDK for collection
  # @return [AssetSnapshot, nil] The created snapshot or nil on failure
  def self.collect_for_asset(asset, use_swarm: false)
    # Option 1: Use Swarm SDK for AI-powered collection
    if use_swarm
      return collect_with_swarm(asset)
    end

    # Option 2: Direct API calls (default)
    # Fetch primary data from Yahoo Finance
    price_data = YahooFinanceService.get_price_data(asset.symbol)

    return nil unless price_data

    # Fetch optional technical indicators from TradingView
    # Note: TradingViewClient is not required - we skip it if not available
    technical_data = nil
    begin
      tv_client = Object.const_get("::TradingViewClient") rescue nil
      if tv_client&.enabled?
        technical_data = tv_client.get_technical_indicators(asset.symbol)
      end
    rescue NameError
      # TradingViewClient not available, continue without it
      Rails.logger.debug "[AssetDataCollector] TradingViewClient not available"
    end

    # Update asset with current price
    asset.update!(
      current_price: price_data[:price],
      last_updated: price_data[:timestamp]
    )

    # Create snapshot
    snapshot = create_snapshot(asset, price_data, technical_data)

    Rails.logger.info "[AssetDataCollector] Collected data for #{asset.symbol}: $#{price_data[:price]}"
    snapshot
  end

  # Collect historical data for an asset
  # @param asset [Asset] The asset to collect historical data for
  # @param interval [String] Time interval (1h, 1d, etc.)
  # @param range [String] Date range (1d, 5d, 1mo, etc.)
  # @return [Integer] Number of snapshots created
  def self.collect_historical_for_asset(asset, interval: "1h", range: "5d")
    historical_data = YahooFinanceService.get_historical_data(asset.symbol, interval:, range:)
    return 0 if historical_data.empty?

    created_count = 0

    historical_data.each do |data_point|
      # Check if snapshot already exists for this timestamp
      existing = asset.asset_snapshots.where(captured_at: data_point[:timestamp]).first

      if existing.nil?
        asset.asset_snapshots.create!(
          price: data_point[:price],
          change_percent: calculate_change_percent(data_point),
          volume: data_point[:volume],
          captured_at: data_point[:timestamp]
        )
        created_count += 1
      end
    end

    Rails.logger.info "[AssetDataCollector] Created #{created_count} historical snapshots for #{asset.symbol}"
    created_count
  end

  # Get summary of collection health
  # @return [Hash] Health status information
  def self.health_status
    assets = Asset.all
    total_assets = assets.count

    # Check recent snapshots (within 4 hours)
    recent_threshold = 4.hours.ago
    assets_with_recent_data = AssetSnapshot.where("captured_at > ?", recent_threshold)
                                           .select(:asset_id)
                                           .distinct
                                           .count

    # Check assets with no recent data
    stale_assets = assets.reject do |asset|
      asset.asset_snapshots.where("captured_at > ?", recent_threshold).exists?
    end

    {
      total_assets:,
      assets_with_recent_data:,
      assets_needing_update: stale_assets.size,
      healthy: assets_with_recent_data == total_assets,
      last_collection_time: AssetSnapshot.order(captured_at: :desc).first&.captured_at,
      stale_asset_symbols: stale_assets.map(&:symbol)
    }
  end

  private

  # Create a snapshot with the collected data
  def self.create_snapshot(asset, price_data, technical_data)
    snapshot = asset.asset_snapshots.create!(
      price: price_data[:price],
      change_percent: price_data[:change_percent],
      volume: price_data[:volume],
      captured_at: price_data[:timestamp]
    )

    # Store technical data if available (can be stored as JSON in a separate column or model)
    # For now, we'll log it - extend schema if needed
    if technical_data
      Rails.logger.debug "[AssetDataCollector] Technical indicators for #{asset.symbol}: #{technical_data}"
    end

    snapshot
  end

  # Calculate change percent from historical data point
  def self.calculate_change_percent(data_point)
    # Simple calculation using open and close
    return nil unless data_point[:open] && data_point[:close] && data_point[:open] > 0

    ((data_point[:close] - data_point[:open]) / data_point[:open] * 100).round(4)
  end

  # Collect data using Swarm SDK multi-agent system
  def self.collect_with_swarm(asset)
    result = SwarmDataCollectorService.collect_for_asset(asset.symbol, asset.asset_type)

    unless result[:success]
      Rails.logger.error "[AssetDataCollector] Swarm collection failed: #{result[:error]}"
      return nil
    end

    # Parse swarm result and extract price data
    # This is a simplified version - actual implementation depends on swarm output format
    price_data = extract_price_from_swarm_result(result[:result])

    return nil unless price_data

    # Update asset with current price
    asset.update!(
      current_price: price_data[:price],
      last_updated: price_data[:timestamp]
    )

    # Create snapshot
    snapshot = create_snapshot(asset, price_data, nil)

    Rails.logger.info "[AssetDataCollector] Collected data via Swarm for #{asset.symbol}: $#{price_data[:price]}"
    snapshot
  rescue StandardError => e
    Rails.logger.error "[AssetDataCollector] Swarm collection error: #{e.message}"
    nil
  end

  # Extract price data from Swarm result
  # This is a simplified parser - enhance based on actual swarm output
  def self.extract_price_from_swarm_result(swarm_result)
    # Try to parse JSON from swarm response
    # This is a fallback - ideally swarm returns structured data directly

    # For now, fall back to direct API if parsing fails
    Rails.logger.warn "[AssetDataCollector] Swarm result parsing not implemented, falling back to direct API"
    YahooFinanceService.get_price_data("AAPL") # This is placeholder
  end
end
