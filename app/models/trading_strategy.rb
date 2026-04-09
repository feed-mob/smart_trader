# frozen_string_literal: true

class TradingStrategy < ApplicationRecord
  belongs_to :trader
  has_many :allocation_decisions, dependent: :nullify
  has_many :trader_reflections, dependent: :nullify
  has_many :strategy_adjustment_logs, dependent: :nullify

  # Enums
  enum :risk_level, { conservative: 0, balanced: 1, aggressive: 2 }
  enum :generated_by, { llm: 0, manual: 1, default_template: 2, matrix: 3 }
  enum :market_condition, { normal: 0, volatile: 1, crash: 2, bubble: 3 }

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :max_positions, inclusion: { in: 2..10 }
  validates :buy_signal_threshold, inclusion: { in: 0.3..0.7 }
  validates :max_position_size, inclusion: { in: 0.3..0.7 }
  validates :min_cash_reserve, inclusion: { in: 0.05..0.4 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :market_condition, uniqueness: { scope: :trader_id }

  # Scopes
  scope :by_risk_level, ->(level) { where(risk_level: level) }
  scope :by_market_condition, ->(condition) { where(market_condition: condition) }

  # Strategy Matrix - 3 risk levels × 4 market conditions = 12 strategies
  STRATEGY_MATRIX = {
    # Normal market
    conservative_normal: {
      name: "Stable Allocation Strategy",
      max_positions: 2, buy_signal_threshold: 0.60,
      max_position_size: 0.40, min_cash_reserve: 0.30,
      description: "Focus on capital preservation, concentrated holdings, strict buy signal filtering, maintain ample cash reserves"
    },
    balanced_normal: {
      name: "Balanced Allocation Strategy",
      max_positions: 3, buy_signal_threshold: 0.50,
      max_position_size: 0.50, min_cash_reserve: 0.20,
      description: "Balance risk and return, moderately diversified holdings, flexible position adjustments"
    },
    aggressive_normal: {
      name: "Growth Strategy",
      max_positions: 4, buy_signal_threshold: 0.40,
      max_position_size: 0.60, min_cash_reserve: 0.10,
      description: "Pursue high returns, diversified holdings, actively capture opportunities, maintain high position levels"
    },

    # Volatile market
    conservative_volatile: {
      name: "Wait and See Strategy",
      max_positions: 2, buy_signal_threshold: 0.65,
      max_position_size: 0.30, min_cash_reserve: 0.40,
      description: "Reduce holdings during high volatility, raise buy threshold, preserve more cash for opportunities"
    },
    balanced_volatile: {
      name: "Moderate Defense Strategy",
      max_positions: 3, buy_signal_threshold: 0.55,
      max_position_size: 0.40, min_cash_reserve: 0.30,
      description: "Moderately reduce positions, raise selection standards, maintain defensive posture"
    },
    aggressive_volatile: {
      name: "Swing Trading Strategy",
      max_positions: 4, buy_signal_threshold: 0.45,
      max_position_size: 0.50, min_cash_reserve: 0.20,
      description: "Utilize volatility for swing trading, quick entry and exit, flexible response"
    },

    # Crash market
    conservative_crash: {
      name: "Capital Preservation Strategy",
      max_positions: 2, buy_signal_threshold: 0.70,
      max_position_size: 0.25, min_cash_reserve: 0.50,
      description: "Prioritize capital preservation during market crash, very low positions, wait for market stabilization"
    },
    balanced_crash: {
      name: "Moderate Dip Buying Strategy",
      max_positions: 3, buy_signal_threshold: 0.50,
      max_position_size: 0.40, min_cash_reserve: 0.30,
      description: "Moderately participate in dip buying, build positions in batches, control risk exposure"
    },
    aggressive_crash: {
      name: "Contrarian Buying Strategy",
      max_positions: 5, buy_signal_threshold: 0.35,
      max_position_size: 0.65, min_cash_reserve: 0.05,
      description: "Contrarian investment, actively buy quality assets during panic, pursue excess returns"
    },

    # Bubble market
    conservative_bubble: {
      name: "Profit Taking Strategy",
      max_positions: 2, buy_signal_threshold: 0.70,
      max_position_size: 0.30, min_cash_reserve: 0.45,
      description: "Gradually take profits during bubble phase, reduce positions, lock in gains"
    },
    balanced_bubble: {
      name: "Gradual Position Reduction Strategy",
      max_positions: 3, buy_signal_threshold: 0.60,
      max_position_size: 0.40, min_cash_reserve: 0.35,
      description: "Gradually reduce positions, increase cash ratio, guard against pullback risk"
    },
    aggressive_bubble: {
      name: "Trend Following Strategy",
      max_positions: 4, buy_signal_threshold: 0.40,
      max_position_size: 0.55, min_cash_reserve: 0.15,
      description: "Follow the trend, set strict stop-loss, take profits timely"
    }
  }.freeze

  # Market condition display names
  MARKET_CONDITION_DISPLAY = {
    "normal" => "Normal Market",
    "volatile" => "Volatile Market",
    "crash" => "Crash Market",
    "bubble" => "Bubble Market"
  }.freeze

  # Class methods
  def self.strategy_matrix
    STRATEGY_MATRIX
  end

  def self.strategy_for(risk_level, market_condition)
    key = "#{risk_level}_#{market_condition}".to_sym
    STRATEGY_MATRIX[key] || STRATEGY_MATRIX[:balanced_normal]
  end

  def self.template_for_risk_level(risk_level)
    strategy_params = strategy_for(risk_level, :normal)
    new(
      name: strategy_params[:name],
      risk_level: risk_level,
      max_positions: strategy_params[:max_positions],
      buy_signal_threshold: strategy_params[:buy_signal_threshold],
      max_position_size: strategy_params[:max_position_size],
      min_cash_reserve: strategy_params[:min_cash_reserve],
      description: strategy_params[:description],
      market_condition: :normal,
      generated_by: :default_template
    )
  end

  # Instance methods
  def display_market_condition
    MARKET_CONDITION_DISPLAY[market_condition]
  end

  def display_generated_by
    { "llm" => "AI Generated", "manual" => "Manual", "default_template" => "Default Template", "matrix" => "Matrix Strategy" }[generated_by]
  end
end
