# frozen_string_literal: true

class FactorDefinition < ApplicationRecord
  # Associations
  has_many :factor_values, dependent: :destroy
  has_many :strategy_factor_weights, dependent: :destroy

  # Categories
  CATEGORIES = {
    'technical' => '技术因子',
    'fundamental' => '基本面因子',
    'sentiment' => '情绪因子',
    'momentum' => '动量因子',
    'risk' => '风险因子',
    'volume' => '成交量因子'
  }.freeze

  # Validations
  validates :code, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :name, presence: true, length: { maximum: 100 }
  validates :category, presence: true, inclusion: { in: CATEGORIES.keys }
  validates :calculation_method, presence: true
  validates :weight, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :update_frequency, numericality: { greater_than: 0 }
  validates :sort_order, numericality: { only_integer: true }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_category, ->(category) { where(category: category) }
  scope :ordered, -> { order(sort_order: :asc, created_at: :asc) }

  # Class methods
  def self.categories_for_select
    CATEGORIES.map { |code, name| [name, code] }
  end

  # Instance methods
  def display_category
    CATEGORIES[category]
  end

  def display_weight
    "#{(weight * 100).round(0)}%"
  end

  def display_status
    active? ? '启用' : '禁用'
  end

  def parameter(key)
    parameters[key.to_s]
  end

  def calculation_days
    parameter(:days) || 20
  end
end
