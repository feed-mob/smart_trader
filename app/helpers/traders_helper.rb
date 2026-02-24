# frozen_string_literal: true

module TradersHelper
  # Format currency with Chinese Yuan symbol
  def format_currency(amount)
    number_to_currency(amount, unit: "¥", precision: 0)
  end

  # Format percentage with sign
  def format_percentage(value)
    return "0%" if value.zero?
    sign = value >= 0 ? "+" : ""
    "#{sign}#{value}%"
  end
end
