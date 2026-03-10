# frozen_string_literal: true

# Frontend Assets Controller - Renders web pages for asset data
class AssetsController < ApplicationController
  # GET /market_assets - List all assets with pagination
  def index
    @assets = Asset.active.includes(:latest_snapshot)
                    .order(last_updated: :desc)
                    .page(params[:page])
                    .per(20)
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
    redirect_to market_assets_path, alert: "Asset not found"
  end

  # GET /assets/:id/analysis - Show AI analysis page
  def analysis
    @asset = Asset.find(params[:id])
    @analysis_hours = (params[:hours] || 48).to_i
  rescue ActiveRecord::RecordNotFound
    redirect_to market_assets_path, alert: "Asset not found"
  end

  private

  def get_top_assets(limit)
    yesterday = Date.yesterday

    # 股票中昨天涨幅最大的 - 使用子查询避免 DISTINCT + ORDER BY 冲突
    top_stock_ids = AssetSnapshot
                          .joins(:asset)
                          .where(assets: { asset_type: 'stock', active: true })
                          .where(snapshot_date: yesterday)
                          .where('change_percent > 0')
                          .order(change_percent: :desc)
                          .limit(limit / 2)
                          .pluck(:asset_id)

    # 加密货币中昨天涨幅最大的
    top_crypto_ids = AssetSnapshot
                          .joins(:asset)
                          .where(assets: { asset_type: 'crypto', active: true })
                          .where(snapshot_date: yesterday)
                          .where('change_percent > 0')
                          .order(change_percent: :desc)
                          .limit(limit - top_stock_ids.size)
                          .pluck(:asset_id)

    # 合并 ID 并查询 Asset
    all_ids = (top_stock_ids + top_crypto_ids).uniq.first(limit)
    Asset.where(id: all_ids).includes(:latest_snapshot)
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
