# frozen_string_literal: true

class Asset < ApplicationRecord
  has_many :asset_snapshots, dependent: :destroy
  has_many :factor_values, dependent: :destroy

  # Validations
  validates :symbol, presence: true, uniqueness: true
  validates :name, presence: true
  validates :asset_type, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(asset_type: type) }

  # Instance methods
  def latest_snapshot
    asset_snapshots.order(captured_at: :desc).first
  end

  def snapshots_in_period(hours: 24)
    asset_snapshots.where('captured_at > ?', hours.hours.ago).order(captured_at: :asc)
  end
end
