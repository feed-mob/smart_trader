# frozen_string_literal: true

# Serializer for AssetSnapshot model
class SnapshotSerializer
  def initialize(resource)
    @resource = resource
  end

  def as_json(*)
    {
      id: @resource.id,
      asset_id: @resource.asset_id,
      asset_symbol: @resource.asset.symbol,
      price: @resource.price,
      change_percent: @resource.change_percent,
      volume: @resource.volume,
      captured_at: @resource.captured_at.iso8601,
      created_at: @resource.created_at.iso8601
    }
  end

  def self.serialize_collection(resources)
    resources.map { |r| new(r).as_json }
  end
end
