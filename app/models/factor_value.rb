# frozen_string_literal: true

class FactorValue < ApplicationRecord
  belongs_to :asset
  belongs_to :factor_definition

  # Validations
  validates :normalized_value, numericality: { greater_than_or_equal_to: -1, less_than_or_equal_to: 1 }, allow_nil: true
  validates :percentile, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :calculated_at, presence: true

  # Scopes
  scope :recent, ->(hours = 24) { where('calculated_at > ?', hours.hours.ago) }
  scope :latest, -> {
    joins("INNER JOIN (
            SELECT asset_id, factor_definition_id, MAX(calculated_at) as max_date
            FROM factor_values
            GROUP BY asset_id, factor_definition_id
           ) latest
           ON factor_values.asset_id = latest.asset_id
           AND factor_values.factor_definition_id = latest.factor_definition_id
           AND factor_values.calculated_at = latest.max_date")
  }
  scope :by_factor, ->(factor_code) { joins(:factor_definition).where(factor_definitions: { code: factor_code }) }

  # Class methods
  def self.latest_for_asset(asset)
    where(asset: asset).latest
  end

  def self.matrix_data(assets, factors)
    values = latest.includes(:asset, :factor_definition)
    values.group_by(&:asset_id).transform_values do |asset_values|
      asset_values.index_by { |v| v.factor_definition.code }
    end
  end
end
