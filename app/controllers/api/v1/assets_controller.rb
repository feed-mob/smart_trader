# frozen_string_literal: true

module Api
  module V1
    class AssetsController < ApplicationController
      # Disable CSRF token requirement for API
      protect_from_forgery with: :null_session

      # Skip authentication for public API endpoints
      skip_before_action :verify_authenticity_token

      # GET /api/v1/assets - List all assets
      def index
        assets = Asset.all.includes(:snapshots)

        render json: {
          success: true,
          data: AssetSerializer.serialize_collection(assets),
          count: assets.count,
          timestamp: Time.current.iso8601
        }
      end

      # GET /api/v1/assets/:id - Get single asset details
      def show
        asset = Asset.find(params[:id])

        render json: {
          success: true,
          data: AssetDetailSerializer.new(asset).as_json
        }
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Asset not found",
          code: "ASSET_NOT_FOUND"
        }, status: :not_found
      end

      # GET /api/v1/assets/:id/snapshots - Get asset snapshots
      def snapshots
        asset = Asset.find(params[:id])

        snapshots = asset.snapshots
                           .where(captured_at: timeframe_range)
                           .order(captured_at: :desc)
                           .limit(100)

        render json: {
          success: true,
          data: SnapshotSerializer.serialize_collection(snapshots),
          count: snapshots.count,
          asset_id: asset.id,
          symbol: asset.symbol,
          timeframe: params[:timeframe] || "24h"
        }
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Asset not found",
          code: "ASSET_NOT_FOUND"
        }, status: :not_found
      end

      # GET /api/v1/assets/:id/latest - Get latest snapshot
      def latest
        asset = Asset.find(params[:id])

        snapshot = asset.latest_snapshot

        if snapshot
          render json: {
            success: true,
            data: SnapshotSerializer.new(snapshot).as_json
          }
        else
          render json: {
            success: false,
            error: "No snapshot data available",
            code: "NO_SNAPSHOT_DATA"
          }, status: :not_found
        end
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Asset not found",
          code: "ASSET_NOT_FOUND"
        }, status: :not_found
      end

      # GET /api/v1/assets/top_by_volume - Get top assets by volume
      def top_by_volume
        limit = (params[:limit] || 10).to_i.clamp(1, 100)

        latest_snapshots = AssetSnapshot
          .select("DISTINCT ON (asset_id) *")
          .order("asset_id, captured_at DESC")

        top_snapshot_ids = latest_snapshots
          .where.not(volume: nil)
          .order(volume: :desc)
          .limit(limit)
          .pluck(:asset_id)

        assets = Asset.where(id: top_snapshot_ids).order("FIELD(id, #{top_snapshot_ids.join(','))")

        render json: {
          success: true,
          data: AssetSerializer.serialize_collection(assets),
          count: assets.count,
          limit: limit,
          timestamp: Time.current.iso8601
        }
      end

      # GET /api/v1/assets/health - API health check
      def health
        health = AssetDataCollector.health_status

        render json: {
          success: true,
          data: {
            status: health[:healthy] ? "healthy" : "unhealthy",
            total_assets: health[:total_assets],
            assets_with_recent_data: health[:assets_with_recent_data],
            assets_needing_update: health[:assets_needing_update],
            last_collection_time: health[:last_collection_time]&.iso8601,
            stale_assets: health[:stale_asset_symbols]
          },
          timestamp: Time.current.iso8601
        }
      end

      # POST /api/v1/assets/collect - Trigger data collection
      def collect
        job = AssetDataCollectionJob.perform_later

        render json: {
          success: true,
          data: {
            message: "Data collection job enqueued",
            job_id: job.job_id
          },
          timestamp: Time.current.iso8601
        }
      rescue StandardError => e
        render json: {
          success: false,
          error: e.message,
          code: "JOB_ENQUEUE_FAILED"
        }, status: :internal_server_error
      end

      private

      # Calculate time range based on timeframe parameter
      def timeframe_range
        timeframe = params[:timeframe] || "24h"

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
        when "90d"
          90.days.ago..Time.current
        else
          24.hours.ago..Time.current
        end
      end
    end
  end
end
