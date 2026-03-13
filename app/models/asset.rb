# frozen_string_literal: true

class Asset < ApplicationRecord
  has_many :asset_snapshots, dependent: :destroy
  has_many :factor_values, dependent: :destroy
  has_many :candles, dependent: :destroy

  # Latest snapshot association for eager loading (prevents N+1 queries)
  has_one :latest_snapshot, -> { order(captured_at: :desc) }, class_name: 'AssetSnapshot'

  # Validations
  validates :symbol, presence: true
  validates :name, presence: true
  validates :asset_type, presence: true
  validates :exchange, presence: true
  validates :quote_currency, presence: true
  validates :symbol, uniqueness: { scope: [:exchange, :quote_currency] }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(asset_type: type) }
  scope :by_exchange, ->(exchange) { where(exchange: exchange) }
  scope :crypto, -> { where(asset_type: 'crypto') }
  scope :stock, -> { where(asset_type: 'stock') }

  def current_price
    latest_snapshot&.price
  end

  def last_updated
    latest_snapshot&.captured_at
  end

  def snapshots_in_period(hours: 24)
    asset_snapshots.where('captured_at > ?', hours.hours.ago).order(captured_at: :asc)
  end

  def trading_pair
    return nil unless asset_type == 'crypto'
    "#{symbol}/#{quote_currency}"
  end

  def full_symbol
    "#{exchange}:#{symbol}"
  end
end
