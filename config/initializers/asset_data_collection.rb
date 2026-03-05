# frozen_string_literal: true

# Configuration for Asset Data Collection Module
# This initializer sets up environment-based configuration for data collectors

Rails.application.config.after_initialize do
  # Log configuration status
  Rails.logger.info "[AssetDataCollection] Initializing..."

  # TradingView MCP Configuration
  tradingview_enabled = ENV["TRADINGVIEW_MCP_ENABLED"] == "true"
  tradingview_endpoint = ENV["TRADINGVIEW_MCP_ENDPOINT"]

  if tradingview_enabled
    if tradingview_endpoint
      Rails.logger.info "[AssetDataCollection] TradingView MCP enabled at #{tradingview_endpoint}"
    else
      Rails.logger.warn "[AssetDataCollection] TradingView MCP enabled but no endpoint configured"
    end
  else
    Rails.logger.info "[AssetDataCollection] TradingView MCP disabled"
  end

  # Yahoo Finance Configuration
  Rails.logger.info "[AssetDataCollection] Yahoo Finance service ready"

  # Redis Cache Configuration (optional, for caching API responses)
  if ENV["REDIS_URL"]
    begin
      redis = Redis.new(url: ENV["REDIS_URL"])
      redis.ping
      Rails.logger.info "[AssetDataCollection] Redis cache connection established"
    rescue StandardError => e
      Rails.logger.error "[AssetDataCollection] Redis connection failed: #{e.message}"
    end
  else
    Rails.logger.info "[AssetDataCollection] No Redis URL configured, using Rails cache"
  end

  # Verify asset seed data exists
  asset_count = Asset.count
  if asset_count.zero?
    Rails.logger.warn "[AssetDataCollection] No assets found. Run `rails db:seed` to create default assets."
  else
    Rails.logger.info "[AssetDataCollection] Found #{asset_count} assets in database"
  end
end
