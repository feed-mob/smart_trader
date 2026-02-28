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
    sort_order: 1,
    formula: <<~FORMULA
      计算公式:
      Momentum = (当前价格 - N日前价格) / N日前价格

      评分规则:
      - 涨幅 0-50% → 评分 0 到 +1
      - 跌幅 0-50% → 评分 0 到 -1
    FORMULA
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
    sort_order: 2,
    formula: <<~FORMULA
      计算公式:
      Volatility = √(Σ(日收益率 - 平均收益率)² / (N-1))

      评分规则:
      - 低波动 → 正分（风险低）
      - 高波动 → 负分（风险高）
    FORMULA
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
    sort_order: 3,
    formula: <<~FORMULA
      计算公式:
      Beta = Cov(资产收益率, 基准收益率) / Var(基准收益率)

      基准选择:
      - 加密货币：BTC
      - 股票：S&P 500 (SPY)
      - 商品：GLD

      评分规则:
      - Beta ≈ 1 → 正分（与市场同步）
      - Beta 偏离1 → 负分（波动异常）
    FORMULA
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
    sort_order: 4,
    formula: <<~FORMULA
      计算公式:
      VR = 上涨日平均成交量 / 下跌日平均成交量

      评分规则:
      - VR > 1.5 → 正分（大资金流入）
      - VR < 0.8 → 负分（资金流出）
      - 0.8-1.5 → 中性
    FORMULA
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
    sort_order: 5,
    formula: <<~FORMULA
      计算方式:
      基于市场涨跌幅分布计算，反映市场整体情绪
    FORMULA
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
    sort_order: 6,
    formula: <<~FORMULA
      计算公式:
      Trend = 线性回归斜率 (N日价格序列)

      评分规则:
      - 斜率 > 0 → 正分（上升趋势）
      - 斜率 < 0 → 负分（下降趋势）
    FORMULA
  },
  # Beta 因子系列 - 相对于不同基准的波动敏感度
  {
    code: 'beta_btc',
    name: 'BTC Beta因子',
    description: '相对于比特币的Beta值，衡量资产相对于BTC的波动敏感度。Beta>1表示波动大于BTC，Beta<1表示波动小于BTC。',
    category: 'risk',
    calculation_method: 'calculate_beta_btc',
    parameters: { days: 20, benchmark: 'BTC-USD' },
    weight: 0.10,
    update_frequency: 60,
    sort_order: 7,
    formula: <<~FORMULA
      计算公式:
      Beta = Cov(资产收益率, BTC收益率) / Var(BTC收益率)

      基准: Bitcoin (BTC-USD)

      评分规则:
      - Beta > 1 → 波动大于BTC
      - Beta ≈ 1 → 与BTC同步
      - Beta < 1 → 波动小于BTC
    FORMULA
  },
  {
    code: 'beta_gold',
    name: '黄金Beta因子',
    description: '相对于黄金的Beta值，衡量资产相对于黄金的波动敏感度。Beta>1表示波动大于黄金，Beta<1表示波动小于黄金。',
    category: 'risk',
    calculation_method: 'calculate_beta_gold',
    parameters: { days: 20, benchmark: 'GC=F' },
    weight: 0.10,
    update_frequency: 60,
    sort_order: 8,
    formula: <<~FORMULA
      计算公式:
      Beta = Cov(资产收益率, 黄金收益率) / Var(黄金收益率)

      基准: 黄金期货 (GC=F)

      评分规则:
      - Beta > 1 → 波动大于黄金
      - Beta ≈ 1 → 与黄金同步
      - Beta < 1 → 波动小于黄金
    FORMULA
  },
  {
    code: 'beta_nvda',
    name: 'NVIDIA Beta因子',
    description: '相对于NVIDIA股票的Beta值，衡量资产相对于NVDA的波动敏感度。Beta>1表示波动大于NVDA，Beta<1表示波动小于NVDA。',
    category: 'risk',
    calculation_method: 'calculate_beta_nvda',
    parameters: { days: 20, benchmark: 'NVDA' },
    weight: 0.10,
    update_frequency: 60,
    sort_order: 9,
    formula: <<~FORMULA
      计算公式:
      Beta = Cov(资产收益率, NVDA收益率) / Var(NVDA收益率)

      基准: NVIDIA (NVDA)

      评分规则:
      - Beta > 1 → 波动大于NVDA
      - Beta ≈ 1 → 与NVDA同步
      - Beta < 1 → 波动小于NVDA
    FORMULA
  },
  {
    code: 'beta_ixic',
    name: '纳斯达克Beta因子',
    description: '相对于纳斯达克指数的Beta值，衡量资产相对于纳斯达克市场的波动敏感度。Beta>1表示波动大于大盘，Beta<1表示波动小于大盘。',
    category: 'risk',
    calculation_method: 'calculate_beta_ixic',
    parameters: { days: 20, benchmark: '^IXIC' },
    weight: 0.10,
    update_frequency: 60,
    sort_order: 10,
    formula: <<~FORMULA
      计算公式:
      Beta = Cov(资产收益率, 纳斯达克收益率) / Var(纳斯达克收益率)

      基准: 纳斯达克指数 (^IXIC)

      评分规则:
      - Beta > 1 → 波动大于大盘
      - Beta ≈ 1 → 与大盘同步
      - Beta < 1 → 波动小于大盘
    FORMULA
  }
]

puts "清空现有数据..."

FactorValue.delete_all
FactorDefinition.delete_all

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