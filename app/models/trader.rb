# frozen_string_literal: true

class Trader < ApplicationRecord
  has_many :trading_strategies, dependent: :destroy

  # Enums
  enum :risk_level, { conservative: 0, balanced: 1, aggressive: 2 }
  enum :status, { active: 0, inactive: 1 }

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :initial_capital, presence: true,
            numericality: { greater_than_or_equal_to: 0 }
  validates :current_capital, allow_nil: true,
            numericality: { greater_than_or_equal_to: 0 }
  validates :description, length: { maximum: 2000 }, allow_blank: true

  # Callbacks
  before_create :set_initial_capital

  # Scopes
  scope :active, -> { where(status: :active) }
  scope :by_risk_level, ->(level) { where(risk_level: level) }
  scope :ordered_by_created, -> { order(created_at: :desc) }

  # Instance methods
  def current_capital_value
    current_capital || initial_capital
  end

  def profit_loss
    return 0 unless current_capital.present?

    current_capital - initial_capital
  end

  def profit_loss_percent
    return 0 unless current_capital.present? && initial_capital.positive?

    ((current_capital - initial_capital) / initial_capital * 100).round(2)
  end

  def display_status
    active? ? "启用" : "停用"
  end

  def display_risk_level
    { "conservative" => "保守", "balanced" => "平衡", "aggressive" => "激进" }[risk_level]
  end

  # Get strategy for a specific market condition
  def strategy_for(market_condition)
    trading_strategies.find_by(market_condition: market_condition)
  end

  # Get all strategies grouped by market condition
  def strategies_by_market_condition
    trading_strategies.index_by(&:market_condition)
  end

  # Check if all strategies exist for all market conditions
  def has_all_strategies?
    TradingStrategy.market_conditions.keys.all? do |condition|
      strategy_for(condition).present?
    end
  end

  # Get first available strategy (for display purposes)
  def default_strategy
    strategy_for(:normal) || trading_strategies.first
  end

  private

  def set_initial_capital
    self.current_capital ||= initial_capital
  end
end
