module ApplicationHelper
  # Render Markdown content
  def render_markdown(text)
    return '' if text.nil?

    require 'kramdown'
    Kramdown::Document.new(text).to_html.html_safe
  rescue LoadError
    # Use simple formatting if kramdown is not available
    simple_format(text)
  end

  # Return style class based on asset type
  def asset_type_badge(type)
    case type.to_s.downcase
    when 'crypto'
      'bg-purple-100 text-purple-800'
    when 'stock'
      'bg-blue-100 text-blue-800'
    when 'forex'
      'bg-green-100 text-green-800'
    when 'commodity'
      'bg-yellow-100 text-yellow-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end

  # Return color class based on price change
  def change_color_class(value)
    value.to_f >= 0 ? 'text-green-600' : 'text-red-600'
  end

  # Format percentage change
  def format_change_percent(value)
    return '-' unless value.present?
    sign = value.to_f >= 0 ? '+' : ''
    "#{sign}#{value.to_f.round(2)}%"
  end

  # Job execution status style class
  def status_badge_class(status)
    case status.to_s.downcase
    when 'success'
      'buy'
    when 'failed'
      'sell'
    when 'running'
      'hold'
    else
      ''
    end
  end

  # Format statistical value
  def format_stat_value(value)
    case value
    when Hash
      value.map { |k, v| "#{k}: #{format_stat_value(v)}" }.join(', ')
    when Array
      value.join(', ')
    when TrueClass, FalseClass
      value ? 'Yes' : 'No'
    else
      value.to_s
    end
  end

  # Job execution status label
  def status_label(status)
    case status.to_s.downcase
    when 'success'
      'Success'
    when 'failed'
      'Failed'
    when 'running'
      'Running'
    else
      status
    end
  end
end
