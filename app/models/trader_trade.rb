# frozen_string_literal: true

class TraderTrade < ApplicationRecord
  ACTIONS = %w[buy sell].freeze

  belongs_to :trader
  belongs_to :allocation_task
  belongs_to :allocation_decision
  belongs_to :asset

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :quantity, :price, :amount, numericality: { greater_than: 0 }
  validates :executed_at, presence: true

  scope :recent, -> { order(executed_at: :desc, created_at: :desc) }
end
