module ApplicationHelper
  # 根据资产类型返回对应的样式类
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

  # 根据涨跌幅返回颜色类
  def change_color_class(value)
    value.to_f >= 0 ? 'text-green-600' : 'text-red-600'
  end

  # 格式化涨跌幅百分比
  def format_change_percent(value)
    return '-' unless value.present?
    sign = value.to_f >= 0 ? '+' : ''
    "#{sign}#{value.to_f.round(2)}%"
  end

  # Job 执行状态样式类
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

  # Job 执行状态标签
  def status_label(status)
    case status.to_s.downcase
    when 'success'
      '成功'
    when 'failed'
      '失败'
    when 'running'
      '运行中'
    else
      status
    end
  end
end
