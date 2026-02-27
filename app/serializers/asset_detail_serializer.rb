# frozen_string_literal: true

# Detailed serializer for Asset model - includes historical data summary
class AssetDetailSerializer
  def initialize(resource)
    @resource = resource
  end

  def as_json(*)
    {
      id: @resource.id,
      symbol: @resource.symbol,
      name: @resource.name,
      asset_type: @resource.asset_type,
      current_price: @resource.current_price,
      last_updated: @resource.last_updated&.iso8601,
      created_at: @resource.created_at.iso8601,
      updated_at: @resource.updated_at.iso8601,
      latest_snapshot: serialize_latest_snapshot,
      statistics: calculate_statistics
    }
  end

  private

  def serialize_latest_snapshot
    return nil unless @resource.latest_snapshot

    snapshot = @resource.latest_snapshot
    {
      id: snapshot.id,
      price: snapshot.price,
      change_percent: snapshot.change_percent,
      volume: snapshot.volume,
      captured_at: snapshot.captured_at.iso8601
    }
  end

  def calculate_statistics
    snapshots = @resource.snapshots
    return basic_stats if snapshots.empty?

    {
      total_snapshots: snapshots.count,
      first_snapshot_at: snapshots.oldest_first.first.captured_at.iso8601,
      last_snapshot_at: snapshots.latest_first.first.captured_at.iso8601,
      price_range: {
        min: snapshots.minimum(:price).to_f,
        max: snapshots.maximum(:price).to_f,
        avg: snapshots.average(:price).to_f.round(2)
      },
      volume_range: {
        max: snapshots.maximum(:volume).to_i
      },
      recent_24h: {
        count: snapshots.recent(24).count,
        avg_price: snapshots.recent(24).average(:price)&.to_f&.round(2) || 0
      }
    }
  end

  def basic_stats
    {
      total_snapshots: 0,
      price_range: { min: 0, max: 0, avg: 0 },
      volume_range: { max: 0 },
      recent_24h: { count: 0, avg_price: 0 }
    }
  end
end
