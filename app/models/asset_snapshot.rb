class AssetSnapshot < ApplicationRecord
  belongs_to :asset

  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :change_percent, numericality: true, allow_nil: true
  validates :volume, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :captured_at, presence: true

  scope :recent, ->(hours = 24) { where(captured_at: hours.hours.ago..Time.current) }
  scope :by_asset, ->(asset_id) { where(asset_id: asset_id) }
end
