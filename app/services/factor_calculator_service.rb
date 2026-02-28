# frozen_string_literal: true

class FactorCalculatorService
  attr_reader :definition, :asset, :params

  def initialize(factor_definition, asset)
    @definition = factor_definition
    @asset = asset
    @params = definition.parameters.with_indifferent_access
  end

  # 计算因子值
  def calculate
    raw_value = send(definition.calculation_method)
    normalized_value = normalize(raw_value)

    {
      raw_value: raw_value,
      normalized_value: normalized_value,
      percentile: nil  # 需要批量计算后才能确定
    }
  rescue => e
    Rails.logger.error("Factor calculation error: #{definition.code} for #{asset&.symbol}: #{e.message}")
    {
      raw_value: nil,
      normalized_value: 0,
      percentile: nil,
      error: e.message
    }
  end

  private

  # ========== 因子计算方法 ==========

  # 动量因子
  def calculate_momentum
    days = params[:days] || 20
    snapshots = asset_snapshots.limit(days + 1)

    return 0 if snapshots.size < 2

    start_price = snapshots.last.price
    end_price = snapshots.first.price

    return 0 if start_price.zero?

    (end_price - start_price) / start_price
  end

  # 波动率因子
  def calculate_volatility
    days = params[:days] || 20
    returns = daily_returns(days)

    return 0 if returns.empty?

    mean = returns.sum / returns.size
    variance = returns.sum { |r| (r - mean) ** 2 } / (returns.size - 1)
    Math.sqrt(variance)
  end

  # 贝塔因子
  def calculate_beta
    days = params[:days] || 20

    # 需要市场基准资产
    market_asset = find_market_benchmark
    return 1.0 unless market_asset

    asset_returns = daily_returns_for(asset, days)
    market_returns = daily_returns_for(market_asset, days)

    return 1.0 if asset_returns.empty? || market_returns.empty?

    covariance = calculate_covariance(asset_returns, market_returns)
    variance = calculate_variance(market_returns)

    return 1.0 if variance.zero?

    covariance / variance
  end

  # 成交量比率因子
  def calculate_volume_ratio
    days = params[:days] || 20
    snapshots = asset_snapshots.limit(days)

    up_days = snapshots.select { |s| s.change_percent.to_f > 0 }
    down_days = snapshots.select { |s| s.change_percent.to_f < 0 }

    return 1.0 if down_days.empty? || up_days.empty?

    avg_up_volume = up_days.sum(&:volume) / up_days.size.to_f
    avg_down_volume = down_days.sum(&:volume) / down_days.size.to_f

    return 1.0 if avg_down_volume.zero?

    avg_up_volume / avg_down_volume
  end

  # 趋势因子
  def calculate_trend
    days = params[:days] || 20
    snapshots = asset_snapshots.limit(days).to_a.reverse

    return 0 if snapshots.size < 2

    prices = snapshots.map(&:price)
    calculate_slope(prices)
  end

  # 情绪因子 (简化版)
  def calculate_sentiment
    # 基于动量的简化情绪指标
    momentum = calculate_momentum
    [[momentum * 2, 1].min, -1].max
  end

  # ========== 标准化方法 ==========

  def normalize(raw_value)
    return 0 if raw_value.nil?

    case definition.code
    when 'momentum'
      normalize_momentum(raw_value)
    when 'volatility'
      normalize_volatility(raw_value)
    when 'beta'
      normalize_beta(raw_value)
    when 'volume_ratio'
      normalize_volume_ratio(raw_value)
    when 'trend'
      normalize_trend(raw_value)
    when 'sentiment'
      raw_value  # 已经是 -1 到 1
    else
      [[raw_value, 1].min, -1].max
    end
  end

  def normalize_momentum(value)
    # 涨幅 0-50% 映射到 0-1，跌幅 0-50% 映射到 0 到 -1
    [[value * 2, 1].min, -1].max
  end

  def normalize_volatility(value)
    # 低波动为正，高波动为负
    # 假设 5% 日波动率为中性点
    volatility_score = 1 - (value * 20)
    [[volatility_score, 1].min, -1].max
  end

  def normalize_beta(value)
    # Beta 接近 1 为正，偏离 1 为负
    deviation = (value - 1).abs
    score = 1 - deviation
    [[score, 1].min, -1].max
  end

  def normalize_volume_ratio(value)
    # VR = 1 为中性，> 1 为正，< 1 为负
    score = (value - 1) / 1.5
    [[score, 1].min, -1].max
  end

  def normalize_trend(value)
    # 斜率标准化
    score = value * 1000
    [[score, 1].min, -1].max
  end

  # ========== 辅助方法 ==========

  def asset_snapshots
    @asset_snapshots ||= asset.asset_snapshots.order(captured_at: :desc)
  end

  def daily_returns(days)
    snapshots = asset_snapshots.limit(days + 1).to_a.reverse
    return [] if snapshots.size < 2

    (1...snapshots.size).map do |i|
      prev_price = snapshots[i - 1].price
      curr_price = snapshots[i].price
      prev_price.zero? ? 0 : (curr_price - prev_price) / prev_price
    end
  end

  def daily_returns_for(target_asset, days)
    return [] unless target_asset

    snapshots = target_asset.asset_snapshots.order(captured_at: :desc).limit(days + 1).to_a.reverse
    return [] if snapshots.size < 2

    (1...snapshots.size).map do |i|
      prev_price = snapshots[i - 1].price
      curr_price = snapshots[i].price
      prev_price.zero? ? 0 : (curr_price - prev_price) / prev_price
    end
  end

  def find_market_benchmark
    return nil unless asset.respond_to?(:asset_type)

    benchmark_symbol = case asset.asset_type
    when 'crypto' then 'BTC'
    when 'stock' then 'SPY'
    when 'commodity' then 'GLD'
    else nil
    end

    return nil unless benchmark_symbol

    # 假设 Asset 有 find_by_symbol 方法
    Asset.find_by(symbol: benchmark_symbol) if defined?(Asset)
  end

  def calculate_covariance(x, y)
    return 0 if x.size != y.size || x.empty?

    mean_x = x.sum / x.size.to_f
    mean_y = y.sum / y.size.to_f

    sum = x.each_with_index.sum do |xi, i|
      (xi - mean_x) * (y[i] - mean_y)
    end

    sum / (x.size - 1).to_f
  end

  def calculate_variance(arr)
    return 0 if arr.empty?

    mean = arr.sum / arr.size.to_f
    sum_squared = arr.sum { |x| (x - mean) ** 2 }

    sum_squared / (arr.size - 1).to_f
  end

  def calculate_slope(values)
    return 0 if values.size < 2

    n = values.size
    x = (0...n).to_a
    y = values

    sum_x = x.sum
    sum_y = y.sum
    sum_xy = x.each_with_index.sum { |xi, i| xi * y[i] }
    sum_xx = x.sum { |xi| xi ** 2 }

    denominator = n * sum_xx - sum_x ** 2
    return 0 if denominator.zero?

    (n * sum_xy - sum_x * sum_y) / denominator.to_f
  end
end
