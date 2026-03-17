# frozen_string_literal: true

class PortfolioSnapshot < ApplicationRecord
  belongs_to :trader
  belongs_to :allocation_task, optional: true

  validates :snapshot_date, :captured_at, :source, presence: true
  validates :cash_value, :invested_value, :portfolio_value, :profit_loss,
            numericality: true
  validates :profit_loss_percent, numericality: true

  scope :recent, -> { order(snapshot_date: :desc, captured_at: :desc) }
end
