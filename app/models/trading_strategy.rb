# frozen_string_literal: true

class TradingStrategy < ApplicationRecord
  belongs_to :trader

  # Enums
  enum :risk_level, { conservative: 0, balanced: 1, aggressive: 2 }
  enum :generated_by, { llm: 0, manual: 1, default_template: 2, matrix: 3 }
  enum :market_condition, { normal: 0, volatile: 1, crash: 2, bubble: 3 }

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :max_positions, inclusion: { in: 2..5 }
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
      name: "稳健配置策略",
      max_positions: 2, buy_signal_threshold: 0.60,
      max_position_size: 0.40, min_cash_reserve: 0.30,
      description: "注重本金保护，持仓集中，严格筛选买入信号，保留充足现金"
    },
    balanced_normal: {
      name: "均衡配置策略",
      max_positions: 3, buy_signal_threshold: 0.50,
      max_position_size: 0.50, min_cash_reserve: 0.20,
      description: "平衡风险与收益，适度分散持仓，灵活调整仓位"
    },
    aggressive_normal: {
      name: "积极成长策略",
      max_positions: 4, buy_signal_threshold: 0.40,
      max_position_size: 0.60, min_cash_reserve: 0.10,
      description: "追求高收益，分散持仓，积极捕捉机会，保持高仓位运作"
    },

    # Volatile market
    conservative_volatile: {
      name: "减仓观望策略",
      max_positions: 2, buy_signal_threshold: 0.65,
      max_position_size: 0.30, min_cash_reserve: 0.40,
      description: "高波动期减少持仓，提高买入门槛，保留更多现金等待机会"
    },
    balanced_volatile: {
      name: "适度防御策略",
      max_positions: 3, buy_signal_threshold: 0.55,
      max_position_size: 0.40, min_cash_reserve: 0.30,
      description: "适度降低仓位，提高选股标准，保持防御姿态"
    },
    aggressive_volatile: {
      name: "波段操作策略",
      max_positions: 4, buy_signal_threshold: 0.45,
      max_position_size: 0.50, min_cash_reserve: 0.20,
      description: "利用波动进行波段操作，快进快出，灵活应对"
    },

    # Crash market
    conservative_crash: {
      name: "防守保本策略",
      max_positions: 2, buy_signal_threshold: 0.70,
      max_position_size: 0.25, min_cash_reserve: 0.50,
      description: "崩盘时期以保本为主，极低仓位，等待市场企稳"
    },
    balanced_crash: {
      name: "小幅抄底策略",
      max_positions: 3, buy_signal_threshold: 0.50,
      max_position_size: 0.40, min_cash_reserve: 0.30,
      description: "适度参与抄底，分批建仓，控制风险敞口"
    },
    aggressive_crash: {
      name: "逆向买入策略",
      max_positions: 5, buy_signal_threshold: 0.35,
      max_position_size: 0.65, min_cash_reserve: 0.05,
      description: "逆向投资，在恐慌中积极买入优质资产，追求超额收益"
    },

    # Bubble market
    conservative_bubble: {
      name: "获利了结策略",
      max_positions: 2, buy_signal_threshold: 0.70,
      max_position_size: 0.30, min_cash_reserve: 0.45,
      description: "泡沫期逐步获利了结，降低仓位，锁定收益"
    },
    balanced_bubble: {
      name: "逐步减仓策略",
      max_positions: 3, buy_signal_threshold: 0.60,
      max_position_size: 0.40, min_cash_reserve: 0.35,
      description: "逐步降低仓位，提高现金比例，防范回调风险"
    },
    aggressive_bubble: {
      name: "趋势跟随策略",
      max_positions: 4, buy_signal_threshold: 0.40,
      max_position_size: 0.55, min_cash_reserve: 0.15,
      description: "顺势而为，跟随趋势但设置严格止损，及时止盈"
    }
  }.freeze

  # Market condition display names
  MARKET_CONDITION_DISPLAY = {
    "normal" => "正常市场",
    "volatile" => "高波动市场",
    "crash" => "崩盘市场",
    "bubble" => "泡沫市场"
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
    { "llm" => "AI 生成", "manual" => "手动配置", "default_template" => "默认模板", "matrix" => "矩阵策略" }[generated_by]
  end
end
