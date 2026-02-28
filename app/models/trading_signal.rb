# frozen_string_literal: true

class TradingSignal < ApplicationRecord
  belongs_to :asset

  SIGNAL_TYPES = %w[buy sell hold].freeze

  validates :signal_type, presence: true, inclusion: { in: SIGNAL_TYPES }
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :generated_at, presence: true

  scope :recent, -> { order(generated_at: :desc) }
  scope :latest, -> { recent.first }
  scope :by_signal_type, ->(type) { where(signal_type: type) }
  scope :buy_signals, -> { where(signal_type: "buy") }
  scope :sell_signals, -> { where(signal_type: "sell") }
  scope :hold_signals, -> { where(signal_type: "hold") }
  scope :high_confidence, -> { where("confidence >= ?", 0.7) }

  # 获取每个资产的最新信号
  def self.latest_for_all_assets
    select("DISTINCT ON (asset_id) *").order("asset_id, generated_at DESC")
  end

  def buy?
    signal_type == "buy"
  end

  def sell?
    signal_type == "sell"
  end

  def hold?
    signal_type == "hold"
  end

  def confidence_percentage
    return 0 if confidence.nil?
    (confidence * 100).round(1)
  end

  def confidence_level
    return "unknown" if confidence.nil?
    case confidence
    when 0.7..1.0
      "high"
    when 0.4...0.7
      "medium"
    else
      "low"
    end
  end

  def signal_type_label
    {
      "buy" => "买入",
      "sell" => "卖出",
      "hold" => "持有"
    }[signal_type] || signal_type
  end
end
