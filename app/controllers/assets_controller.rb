# frozen_string_literal: true

# Frontend Assets Controller - Renders web pages for asset data
class AssetsController < ApplicationController
  # GET /assets - List all assets
  def index
    @assets = Asset.all.includes(:latest_snapshot)
  end

  # GET /assets/:id - Show asset detail page
  def show
    @asset = Asset.find(params[:id])

    # Get snapshots based on timeframe parameter
    timeframe = params[:timeframe] || "24h"

    @snapshots = @asset.snapshots
                        .where(captured_at: parse_timeframe(timeframe))
                        .order(captured_at: :desc)
                        .limit(200)

    @timeframe = timeframe
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
