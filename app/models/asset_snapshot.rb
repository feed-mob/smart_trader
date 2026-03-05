# frozen_string_literal: true

class AssetSnapshot < ApplicationRecord
  self.table_name = 'asset_snapshots'
  belongs_to :asset

  # Validations
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :captured_at, presence: true

  # Scopes
  scope :recent, ->(hours = 24) { where('captured_at > ?', hours.hours.ago) }
  scope :by_asset, ->(asset_id) { where(asset_id: asset_id) }

  # Class methods
  def self.latest_for_asset(asset)
    where(asset: asset).order(captured_at: :desc).first
  end
end
