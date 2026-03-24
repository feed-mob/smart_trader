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
      "all" => "全部",
      "1h" => "1小时",
      "6h" => "6小时",
      "24h" => "24小时",
      "7d" => "7天",
      "30d" => "30天"
    }
    labels[tf] || tf
  end

  # Returns CSS class for active timeframe button
  def active_timeframe_class(tf)
    tf == @timeframe ? "timeframe-btn--active" : ""
  end
end
