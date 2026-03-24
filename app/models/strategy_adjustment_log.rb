# frozen_string_literal: true

class StrategyAdjustmentLog < ApplicationRecord
  belongs_to :trader_reflection
  belongs_to :trading_strategy

  validates :parameter, :direction, :applied_at, presence: true
end
