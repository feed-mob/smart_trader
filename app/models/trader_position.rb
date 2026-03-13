# frozen_string_literal: true

class TraderPosition < ApplicationRecord
  belongs_to :trader
  belongs_to :asset

  validates :quantity, :average_cost, :current_price, :market_value,
            numericality: { greater_than_or_equal_to: 0 }
  validates :unrealized_pnl, numericality: true
  validates :unrealized_pnl_percent, numericality: true
  validates :asset_id, uniqueness: { scope: :trader_id }

  scope :active, -> { where(active: true) }
  scope :ordered_by_value, -> { order(market_value: :desc) }
end
