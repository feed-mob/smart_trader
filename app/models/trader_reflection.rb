# frozen_string_literal: true

class TraderReflection < ApplicationRecord
  belongs_to :trader
  belongs_to :trading_strategy, optional: true
  has_many :strategy_adjustment_logs, dependent: :destroy

  enum :status, { pending: 0, generated: 1, failed: 2 }

  validates :reflection_period_start, :reflection_period_end, :source, :prompt_version, presence: true

  scope :recent, -> { order(reflection_period_end: :desc, created_at: :desc) }
end
