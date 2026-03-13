# frozen_string_literal: true

# AssetsHelper provides helper methods for asset views
module AssetsHelper
  # Returns CSS class for asset type badge
  def asset_type_badge(type)
    badges = {
      'crypto' => 'bg-orange-100 text-orange-800',
      'stock' => 'bg-blue-100 text-blue-800',
      'commodity' => 'bg-yellow-100 text-yellow-800'
    }
    badges[type.to_s.downcase] || 'bg-gray-100 text-gray-800'
  end

  # Returns CSS class for change percentage (positive/negative)
  def change_color_class(change)
    if change.nil?
      'text-gray-500'
    elsif change >= 0
      'text-green-600'
    else
      'text-red-600'
    end
  end

  # Formats change percentage with sign
  def format_change_percent(change)
    return '-' if change.nil?
    sign = change >= 0 ? '+' : ''
    "#{sign}#{change.round(2)}%"
  end

  # Returns human-readable label for timeframe
  def timeframe_label(tf)
    labels = {
      '1h' => '1小时',
      '6h' => '6小时',
      '24h' => '24小时',
      '7d' => '7天',
      '30d' => '30天'
    }
    labels[tf] || tf
  end

  # Returns CSS class for active timeframe button
  def active_timeframe_class(tf)
    tf == @timeframe ? 'bg-blue-500 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
  end
end
