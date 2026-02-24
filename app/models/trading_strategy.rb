# frozen_string_literal: true

class TradingStrategy < ApplicationRecord
  belongs_to :trader

  # Enums
  enum :risk_level, { conservative: 0, balanced: 1, aggressive: 2 }
  enum :generated_by, { llm: 0, manual: 1, default_template: 2 }

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :max_positions, inclusion: { in: 2..5 }
  validates :buy_signal_threshold, inclusion: { in: 0.3..0.7 }
  validates :max_position_size, inclusion: { in: 0.3..0.7 }
  validates :min_cash_reserve, inclusion: { in: 0.05..0.4 }
  validates :description, length: { maximum: 500 }, allow_blank: true

  # Scopes
  scope :by_risk_level, ->(level) { where(risk_level: level) }

  # Class methods - 默认策略模板
  def self.conservative_template
    new(
      name: "稳健价值投资策略",
      risk_level: :conservative,
      max_positions: 2,
      buy_signal_threshold: 0.6,
      max_position_size: 0.4,
      min_cash_reserve: 0.3,
      description: "注重本金保护，持仓集中，严格筛选买入信号，保留充足现金应对波动",
      generated_by: :default_template
    )
  end

  def self.balanced_template
    new(
      name: "均衡配置策略",
      risk_level: :balanced,
      max_positions: 3,
      buy_signal_threshold: 0.5,
      max_position_size: 0.5,
      min_cash_reserve: 0.2,
      description: "平衡风险与收益，适度分散持仓，灵活调整仓位",
      generated_by: :default_template
    )
  end

  def self.aggressive_template
    new(
      name: "激进成长策略",
      risk_level: :aggressive,
      max_positions: 4,
      buy_signal_threshold: 0.4,
      max_position_size: 0.6,
      min_cash_reserve: 0.1,
      description: "追求高收益，分散持仓，积极捕捉机会，保持高仓位运作",
      generated_by: :default_template
    )
  end

  def self.template_for_risk_level(risk_level)
    case risk_level.to_s
    when "conservative" then conservative_template
    when "aggressive" then aggressive_template
    else balanced_template
    end
  end
end
