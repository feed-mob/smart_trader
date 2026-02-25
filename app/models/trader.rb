# frozen_string_literal: true

class Trader < ApplicationRecord
  has_one :trading_strategy, dependent: :destroy

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

  private

  def set_initial_capital
    self.current_capital ||= initial_capital
  end
end
