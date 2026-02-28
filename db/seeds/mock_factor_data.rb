# frozen_string_literal: true

# Mock 数据生成脚本
# 使用方法: bundle exec rails runner db/seeds/mock_factor_data.rb

puts "开始生成 Mock 数据..."

# 创建资产
assets_data = [
  { symbol: 'BTC', name: 'Bitcoin', asset_type: 'crypto' },
  { symbol: 'ETH', name: 'Ethereum', asset_type: 'crypto' },
  { symbol: 'AAPL', name: 'Apple Inc.', asset_type: 'stock' },
  { symbol: 'NVDA', name: 'NVIDIA Corporation', asset_type: 'stock' },
  { symbol: 'GLD', name: 'SPDR Gold Shares', asset_type: 'commodity' }
]

assets_data.each do |data|
  asset = Asset.find_or_create_by!(symbol: data[:symbol]) do |a|
    a.name = data[:name]
    a.asset_type = data[:asset_type]
  end
  puts "Created asset: #{asset.symbol}"
end

# 创建资产快照 (过去30天的模拟数据)
Asset.all.each do |asset|
  base_price = case asset.symbol
  when 'BTC' then 65000.0
  when 'ETH' then 3500.0
  when 'AAPL' then 180.0
  when 'NVDA' then 800.0
  when 'GLD' then 200.0
  else 100.0
  end

  30.times do |i|
    days_ago = 30 - i
    captured_at = days_ago.days.ago

    # 模拟价格波动
    random_change = rand(-5..5) / 100.0
    price = base_price * (1 + random_change * i * 0.1)
    change_percent = rand(-5.0..5.0)
    volume = rand(1_000_000..10_000_000)

    AssetSnapshot.create!(
      asset: asset,
      price: price,
      change_percent: change_percent,
      volume: volume,
      captured_at: captured_at
    )
  end
  puts "Created 30 snapshots for: #{asset.symbol}"
end

# 创建因子值
Asset.all.each do |asset|
  FactorDefinition.active.each do |factor|
    # 模拟因子值
    raw_value = rand(-0.5..0.8)
    normalized_value = [[raw_value, 1].min, -1].max
    percentile = rand(10..90)

    FactorValue.create!(
      asset: asset,
      factor_definition: factor,
      raw_value: raw_value,
      normalized_value: normalized_value,
      percentile: percentile,
      calculated_at: Time.current
    )
  end
  puts "Created factor values for: #{asset.symbol}"
end

puts ""
puts "Mock data created successfully!"
puts "Assets: #{Asset.count}"
puts "Snapshots: #{AssetSnapshot.count}"
puts "Factor Values: #{FactorValue.count}"
