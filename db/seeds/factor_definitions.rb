# frozen_string_literal: true

# 因子定义种子数据
# 使用方法: rails runner db/seeds/factor_definitions.rb

factors_data = [
  {
    code: 'momentum',
    name: '动量因子',
    description: '过去N日价格涨跌幅，反映价格趋势强度。涨幅越大评分越高，跌幅越大评分越低。',
    category: 'momentum',
    calculation_method: 'calculate_momentum',
    parameters: { days: 20 },
    weight: 0.20,
    update_frequency: 60,
    sort_order: 1
  },
  {
    code: 'volatility',
    name: '波动率因子',
    description: '过去N日价格波动率，衡量风险水平。低波动为正分（风险低），高波动为负分（风险高）。',
    category: 'risk',
    calculation_method: 'calculate_volatility',
    parameters: { days: 20 },
    weight: 0.15,
    update_frequency: 60,
    sort_order: 2
  },
  {
    code: 'beta',
    name: '贝塔因子',
    description: '相对于市场基准的波动敏感度。Beta接近1为正分（与市场同步），偏离1为负分（波动异常）。',
    category: 'risk',
    calculation_method: 'calculate_beta',
    parameters: { days: 20 },
    weight: 0.15,
    update_frequency: 60,
    sort_order: 3
  },
  {
    code: 'volume_ratio',
    name: '成交量比率因子',
    description: '上涨日平均成交量/下跌日平均成交量，反映大资金流向。VR>1.5为大资金流入，VR<0.8为资金流出。',
    category: 'volume',
    calculation_method: 'calculate_volume_ratio',
    parameters: { days: 20, threshold: 1.5 },
    weight: 0.20,
    update_frequency: 60,
    sort_order: 4
  },
  {
    code: 'sentiment',
    name: '情绪因子',
    description: '市场恐惧贪婪指数的简化版本，基于市场涨跌幅分布计算。',
    category: 'sentiment',
    calculation_method: 'calculate_sentiment',
    parameters: {},
    weight: 0.15,
    update_frequency: 60,
    sort_order: 5
  },
  {
    code: 'trend',
    name: '趋势因子',
    description: '均线趋势强度，使用N日价格线性回归斜率计算。斜率>0为上升趋势，斜率<0为下降趋势。',
    category: 'technical',
    calculation_method: 'calculate_trend',
    parameters: { days: 20 },
    weight: 0.15,
    update_frequency: 60,
    sort_order: 6
  }
]

puts "正在创建因子定义..."

factors_data.each do |factor_attrs|
  factor = FactorDefinition.find_or_initialize_by(code: factor_attrs[:code])
  factor.assign_attributes(factor_attrs)

  if factor.save
    action = factor.previously_new_record? ? '创建' : '更新'
    puts "✓ #{action}: #{factor.name} (#{factor.code})"
  else
    puts "✗ 失败: #{factor_attrs[:name]} - #{factor.errors.full_messages.join(', ')}"
  end
end

puts "\n因子定义创建完成!"
puts "总计: #{FactorDefinition.count} 个因子"
puts "启用: #{FactorDefinition.active.count} 个"
puts "禁用: #{FactorDefinition.inactive.count} 个"
