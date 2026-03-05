# frozen_string_literal: true

# Serializer for Asset model - API response format
class AssetSerializer
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
      latest_snapshot: serialize_latest_snapshot
    }
  end

  def self.serialize_collection(resources)
    resources.map { |r| new(r).as_json }
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
end
