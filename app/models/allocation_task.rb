# frozen_string_literal: true

class AllocationTask < ApplicationRecord
  belongs_to :trader
  belongs_to :allocation_decision, optional: true
  has_one :portfolio_snapshot, dependent: :destroy
  has_many :trader_trades, dependent: :destroy

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3, skipped: 4 }

  validates :run_on, presence: true
  validates :starting_cash, :ending_cash, :portfolio_value,
            numericality: { greater_than_or_equal_to: 0 }

  scope :recent, -> { order(run_on: :desc, created_at: :desc) }
end
