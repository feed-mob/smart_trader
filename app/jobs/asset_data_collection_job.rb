# frozen_string_literal: true

# Background job for collecting asset data
# Collects data for top 10 assets by trading volume
class AssetDataCollectionJob < ApplicationJob
  queue_as :default

  # Retry on network errors with exponential backoff
  retry_on Net::OpenTimeout, wait: :exponentially_longer, attempts: 3
  retry_on HTTParty::Error, wait: :exponentially_longer, attempts: 3

  # Number of top assets to collect by volume
  TOP_ASSETS_LIMIT = 10

  def perform
    Rails.logger.info "[AssetDataCollectionJob] Starting at #{Time.current}"

    # Get top assets by volume (last snapshot)
    top_assets = get_top_volume_assets

    Rails.logger.info "[AssetDataCollectionJob] Collecting data for #{top_assets.size} assets"

    results = { success: 0, failed: 0, errors: [] }

    top_assets.each do |asset|
      begin
        collect_and_store_asset_data(asset)
        results[:success] += 1
      rescue StandardError => e
        results[:failed] += 1
        results[:errors] << { symbol: asset.symbol, error: e.message }
        Rails.logger.error "[AssetDataCollectionJob] Failed for #{asset.symbol}: #{e.message}"
      end
    end

    # Log summary
    Rails.logger.info "[AssetDataCollectionJob] Completed: #{results[:success]} success, #{results[:failed]} failed"
  end

  private

  # Get top assets by trading volume
  # Uses most recent snapshot for each asset
  def get_top_volume_assets
    # Get latest snapshot for each asset
    latest_snapshots = AssetSnapshot
      .select("DISTINCT ON (asset_id) *")
      .order("asset_id, captured_at DESC")

    # Sort by volume and get top N
    top_snapshot_ids = latest_snapshots
      .where.not(volume: nil)
      .order(volume: :desc)
      .limit(TOP_ASSETS_LIMIT)
      .pluck(:asset_id)

    # If no snapshots exist yet, return all assets
    if top_snapshot_ids.empty?
      Rails.logger.warn "[AssetDataCollectionJob] No snapshots found, collecting for all assets"
      return Asset.limit(TOP_ASSETS_LIMIT)
    end

    Asset.where(id: top_snapshot_ids).order("id ASC")
  end

  # Collect and store data for a single asset
  def collect_and_store_asset_data(asset)
    # Use AssetDataCollector which now supports TradingView MCP for crypto
    result = AssetDataCollector.collect_for_asset(asset)

    return unless result

    Rails.logger.debug "[AssetDataCollectionJob] Collected #{asset.symbol}: $#{result[:price]} (Vol: #{result[:volume]})"
  end
end
