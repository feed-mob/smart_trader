# frozen_string_literal: true

class AllocationDecision < ApplicationRecord
  belongs_to :trader
  belongs_to :trading_strategy, optional: true
  has_many :allocation_tasks, dependent: :nullify
  has_many :trader_trades, dependent: :nullify

  enum :status, { pending: 0, generated: 1, invalid_payload: 2, failed: 3 }
  enum :validation_status, { pending_validation: 0, valid_payload: 1, invalid_payload: 2 }, prefix: :validation

  validates :decision_date, presence: true
  validates :source, presence: true
  validates :recommendation_payload, presence: true

  scope :recent, -> { order(decision_date: :desc, created_at: :desc) }
  scope :successful, -> { where(status: :generated, validation_status: :valid_payload) }

  def recommendation_payload_symbolized
    recommendation_payload.deep_symbolize_keys
  end
end
