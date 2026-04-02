# frozen_string_literal: true

# AssetsHelper provides helper methods for asset views
module AssetsHelper
  # Returns CSS class for asset type badge
  def asset_type_badge(type)
    badges = {
      "crypto" => "asset-type-badge--crypto",
      "stock" => "asset-type-badge--stock",
      "forex" => "asset-type-badge--forex",
      "commodity" => "asset-type-badge--commodity"
    }
    badges[type.to_s.downcase] || "asset-type-badge--stock"
  end

  # Returns CSS class for change percentage (positive/negative)
  def change_color_class(change)
    if change.nil?
      "text-gray-500"
    elsif change >= 0
      "text-green-600"
    else
      "text-red-600"
    end
  end

  # Formats change percentage with sign
  def format_change_percent(change)
    return "-" if change.nil?
    sign = change >= 0 ? "+" : ""
    "#{sign}#{change.round(2)}%"
  end

  # Returns human-readable label for timeframe
  def timeframe_label(tf)
    labels = {
      "all" => "All",
      "1h" => "1h",
      "6h" => "6h",
      "24h" => "24h",
      "7d" => "7d",
      "30d" => "30d"
    }
    labels[tf] || tf
  end

  # Returns CSS class for active timeframe button
  def active_timeframe_class(tf)
    tf == @timeframe ? "timeframe-btn--active" : ""
  end
end
