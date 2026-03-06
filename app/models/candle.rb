# frozen_string_literal: true

class Candle < ApplicationRecord
  belongs_to :asset

  # Validations
  validates :interval, presence: true
  validates :candle_time, presence: true
  validates :open_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :high_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :low_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :close_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :candle_time, uniqueness: { scope: [:asset_id, :interval] }

  validate :price_consistency

  # Scopes
  scope :by_asset, ->(asset_id) { where(asset_id: asset_id) }
  scope :by_interval, ->(interval) { where(interval: interval) }
  scope :four_hours, -> { where(interval: '4h') }
  scope :daily, -> { where(interval: '1d') }
  scope :recent, ->(limit = 100) { order(candle_time: :desc).limit(limit) }
  scope :time_range, ->(start_time, end_time) { where(candle_time: start_time..end_time) }

  # Intervals
  INTERVALS = %w[1m 5m 15m 1h 4h 1d 1w].freeze

  # Class methods
  def self.latest_for_asset(asset, interval = '4h')
    where(asset: asset, interval: interval).order(candle_time: :desc).first
  end

  def self.for_time(asset, interval, time)
    find_by(asset: asset, interval: interval, candle_time: time)
  end

  # Instance methods
  def price_change
    return nil if open_price.zero?
    ((close_price - open_price) / open_price * 100).round(4)
  end

  def price_change_abs
    close_price - open_price
  end

  def volatility
    return nil if low_price.zero?
    ((high_price - low_price) / low_price * 100).round(4)
  end

  def bullish?
    close_price > open_price
  end

  def bearish?
    close_price < open_price
  end

  private

  def price_consistency
    return unless high_price && low_price && open_price && close_price

    if high_price < low_price
      errors.add(:high_price, "cannot be less than low price")
    end

    if high_price < open_price || high_price < close_price
      errors.add(:high_price, "must be the highest price")
    end

    if low_price > open_price || low_price > close_price
      errors.add(:low_price, "must be the lowest price")
    end
  end
end
