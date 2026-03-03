# frozen_string_literal: true

# Mock 交易信号数据生成脚本
# 使用方法: bundle exec rails runner db/seeds/mock_trading_signals.rb

puts "开始生成 Mock 交易信号..."

# 确保有资产和因子数据
if Asset.count.zero?
  puts "错误: 请先运行 mock_factor_data.rb 创建资产数据"
  exit 1
end

# 信号模板
signal_templates = [
  {
    signal_type: "buy",
    confidence_range: 0.65..0.85,
    reasoning_templates: [
      "多因子共振向上，动量强劲，成交量放大显示资金流入，趋势明确。",
      "技术面和情绪面双重利好，短期看涨信号明确。",
      "突破关键阻力位，成交量配合，建议逢低建仓。"
    ],
    key_factors_options: [
      [ "动量因子", "成交量比率", "趋势因子" ],
      [ "趋势因子", "情绪因子" ],
      [ "动量因子", "成交量比率" ]
    ],
    risk_options: [
      "需关注上方阻力位突破情况",
      "注意市场整体波动风险",
      nil
    ]
  },
  {
    signal_type: "sell",
    confidence_range: 0.55..0.75,
    reasoning_templates: [
      "多因子转弱，动量衰减，成交量萎缩，建议减仓。",
      "技术面出现顶部信号，风险收益比不佳。",
      "短期上涨动力不足，建议获利了结。"
    ],
    key_factors_options: [
      [ "波动率因子", "趋势因子" ],
      [ "动量因子", "贝塔因子" ],
      [ "成交量比率", "情绪因子" ]
    ],
    risk_options: [
      "若突破前高需重新评估",
      "注意止损设置",
      nil
    ]
  },
  {
    signal_type: "hold",
    confidence_range: 0.40..0.60,
    reasoning_templates: [
      "因子信号不明确，建议观望等待更清晰信号。",
      "多空因素交织，短期方向不明，维持当前仓位。",
      "市场震荡，无明确操作机会，建议持有观望。"
    ],
    key_factors_options: [
      [ "波动率因子", "情绪因子" ],
      [ "贝塔因子" ],
      [ "成交量比率" ]
    ],
    risk_options: [
      "关注市场方向选择",
      nil,
      nil
    ]
  }
]

# 为每个资产生成信号
Asset.all.each do |asset|
  # 随机选择信号类型
  template = signal_templates.sample

  # 随机生成信号数据
  signal_type = template[:signal_type]
  confidence = rand(template[:confidence_range]).round(2)
  reasoning = template[:reasoning_templates].sample
  key_factors = template[:key_factors_options].sample
  risk_warning = template[:risk_options].sample

  # 获取该资产的因子快照
  factor_snapshot = {}
  FactorValue.where(asset: asset).includes(:factor_definition).each do |fv|
    factor_snapshot[fv.factor_definition.code] = {
      name: fv.factor_definition.name,
      normalized_value: fv.normalized_value,
      percentile: fv.percentile,
      weight: fv.factor_definition.weight
    }
  end

  # 创建信号
  signal = TradingSignal.create!(
    asset: asset,
    signal_type: signal_type,
    confidence: confidence,
    reasoning: reasoning,
    key_factors: key_factors,
    risk_warning: risk_warning,
    factor_snapshot: factor_snapshot,
    generated_at: Time.current - rand(0..6).hours
  )

  puts "Created #{signal_type.upcase} signal for #{asset.symbol} (confidence: #{(confidence * 100).round(0)}%)"
end

# 为部分资产创建历史信号
puts ""
puts "Creating historical signals..."

Asset.all.sample(3).each do |asset|
  3.times do |i|
    template = signal_templates.sample
    factor_snapshot = {}
    FactorValue.where(asset: asset).includes(:factor_definition).each do |fv|
      factor_snapshot[fv.factor_definition.code] = {
        name: fv.factor_definition.name,
        normalized_value: fv.normalized_value + rand(-0.2..0.2),
        percentile: fv.percentile,
        weight: fv.factor_definition.weight
      }
    end

    TradingSignal.create!(
      asset: asset,
      signal_type: template[:signal_type],
      confidence: rand(template[:confidence_range]).round(2),
      reasoning: template[:reasoning_templates].sample,
      key_factors: template[:key_factors_options].sample,
      risk_warning: template[:risk_options].sample,
      factor_snapshot: factor_snapshot,
      generated_at: (i + 1).days.ago
    )
  end
  puts "Created 3 historical signals for #{asset.symbol}"
end

puts ""
puts "Mock trading signals created successfully!"
puts "Total signals: #{TradingSignal.count}"
puts "Buy signals: #{TradingSignal.buy_signals.count}"
puts "Sell signals: #{TradingSignal.sell_signals.count}"
puts "Hold signals: #{TradingSignal.hold_signals.count}"
