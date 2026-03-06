# frozen_string_literal: true

class AssetSnapshot < ApplicationRecord
  self.table_name = 'asset_snapshots'
  belongs_to :asset

  # Validations
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :snapshot_date, presence: true
  validates :captured_at, presence: true
  validates :snapshot_date, uniqueness: { scope: :asset_id }

  # Scopes
  scope :recent, ->(days = 30) { where('snapshot_date >= ?', days.days.ago.to_date) }
  scope :by_asset, ->(asset_id) { where(asset_id: asset_id) }
  scope :by_date, ->(date) { where(snapshot_date: date) }
  scope :date_range, ->(start_date, end_date) { where(snapshot_date: start_date..end_date) }

  # Class methods
  def self.latest_for_asset(asset)
    where(asset: asset).order(snapshot_date: :desc).first
  end

  def self.for_date(asset, date)
    find_by(asset: asset, snapshot_date: date)
  end
end
