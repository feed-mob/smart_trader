# frozen_string_literal: true

# Frontend Assets Controller - Renders web pages for asset data
class AssetsController < ApplicationController
  # GET /assets - List all assets
  def index
    @assets = Asset.all.includes(:asset_snapshots)
    @top_assets = get_top_assets(6)
  end

  # GET /assets/:id - Show asset detail page
  def show
    @asset = Asset.find(params[:id])
    @timeframe = params[:timeframe] || "24h"
    @snapshots = @asset.asset_snapshots
                      .where(captured_at: parse_timeframe(@timeframe))
                      .order(captured_at: :desc)
                      .limit(200)
  rescue ActiveRecord::RecordNotFound
    redirect_to assets_path, alert: "Asset not found"
  end

  # GET /assets/:id/analysis - Show AI analysis page
  def analysis
    @asset = Asset.find(params[:id])
    @analysis_hours = (params[:hours] || 48).to_i
  rescue ActiveRecord::RecordNotFound
    redirect_to assets_path, alert: "Asset not found"
  end

  private

  def get_top_assets(limit)
    # Yahoo Finance热门股票 - 随机3条
    yahoo_assets = Asset.active
                        .where(asset_type: 'stock')
                        .order('RANDOM()')
                        .limit(3)

    # CoinGecko热门加密货币 - 随机3条
    coingecko_assets = Asset.active
                            .where(asset_type: 'crypto')
                            .order('RANDOM()')
                            .limit(3)

    # 合并并去重
    (yahoo_assets + coingecko_assets).uniq.first(limit)
  end

  # Parse timeframe string to range
  def parse_timeframe(timeframe)
    case timeframe
    when "1h"
      1.hour.ago..Time.current
    when "6h"
      6.hours.ago..Time.current
    when "24h"
      24.hours.ago..Time.current
    when "7d"
      7.days.ago..Time.current
    when "30d"
      30.days.ago..Time.current
    else
      24.hours.ago..Time.current
    end
  end
end
