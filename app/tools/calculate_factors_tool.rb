# frozen_string_literal: true

# 因子计算工具
# 让 AI Agent 可以基于现有的 FactorDefinition 计算资产的因子值（只读查询）
class CalculateFactorsTool < RubyLLM::Tool
  description "为资产计算因子值并返回结果，使用数据库中已配置的 FactorDefinition（不保存数据）"
  param :symbols, type: :array, required: false,
        desc: "资产代码数组，如 ['BTCUSDT', 'ETHUSDT']，不传则计算所有资产"
  param :factor_codes, type: :array, required: false,
        desc: "因子代码数组，如 ['rsi_14', 'momentum_7d']，不传则计算所有活跃因子"
  param :use_cache, type: :boolean, required: false,
        desc: "是否使用缓存的因子值（1小时内），默认 true"

  def execute(symbols: nil, factor_codes: nil, use_cache: true)
    # 获取资产
    assets = Asset.active
    assets = assets.where(symbol: symbols) if symbols.present?
    assets = assets.limit(50).to_a

    return { success: false, error: "未找到匹配的资产" } if assets.empty?

    # 获取因子定义（使用数据库中已配置的）
    factor_definitions = FactorDefinition.active.ordered
    factor_definitions = factor_definitions.where(code: factor_codes) if factor_codes.present?
    factor_definitions = factor_definitions.to_a

    return { success: false, error: "未找到活跃的因子定义" } if factor_definitions.empty?

    # 为每个资产计算/查询因子
    results = []

    assets.each do |asset|
      asset_factors = calculate_factors_for_asset(asset, factor_definitions, use_cache)
      results << {
        symbol: asset.symbol,
        name: asset.name,
        factors: asset_factors
      }
    end

    {
      success: true,
      assets_count: assets.size,
      factor_definitions_used: factor_definitions.map { |fd| { code: fd.code, name: fd.name, category: fd.category } },
      results: results
    }
  rescue StandardError => e
    { success: false, error: e.message, backtrace: e.backtrace&.first(5) }
  end

  private

  # 为单个资产计算/查询因子（只读）
  def calculate_factors_for_asset(asset, factor_definitions, use_cache)
    # 获取历史快照数据
    snapshots = asset.snapshots_in_period(hours: 168) # 7天数据
    latest_snapshot = asset.latest_snapshot

    factor_definitions.map do |factor_def|
      # 尝试从缓存获取
      if use_cache
        existing = FactorValue.where(asset: asset, factor_definition: factor_def)
          .where("calculated_at > ?", 1.hour.ago)
          .first

        if existing
          next {
            code: factor_def.code,
            name: factor_def.name,
            category: factor_def.category,
            value: existing.raw_value,
            normalized_value: existing.normalized_value,
            percentile: existing.percentile,
            source: "cache"
          }
        end
      end

      # 实时计算
      value = calculate_factor_value(factor_def, snapshots, latest_snapshot)

      if value.nil?
        next {
          code: factor_def.code,
          name: factor_def.name,
          category: factor_def.category,
          value: nil,
          normalized_value: nil,
          percentile: nil,
          source: "calculation_failed"
        }
      end

      # 计算标准化值和百分位
      normalized_value = normalize_factor_value(value, factor_def)
      percentile = calculate_percentile(value, factor_def)

      {
        code: factor_def.code,
        name: factor_def.name,
        category: factor_def.category,
        value: value.round(4),
        normalized_value: normalized_value.round(4),
        percentile: percentile.round(1),
        source: "calculated"
      }
    end
  end

  # 根据因子定义计算因子值
  def calculate_factor_value(factor_def, snapshots, latest_snapshot)
    case factor_def.code
    when /change_15m/, /momentum_15m/
      calculate_change_from_snapshot(latest_snapshot)
    when /momentum_7d/
      calculate_momentum(snapshots, 7)
    when /momentum_30d/
      calculate_momentum(snapshots, 30)
    when /volatility_7d/
      calculate_volatility(snapshots, 7)
    when /volatility_30d/
      calculate_volatility(snapshots, 30)
    when /rsi_14/
      calculate_rsi(snapshots, 14)
    when /rsi_7/
      calculate_rsi(snapshots, 7)
    when /bb_position/, /bollinger_position/
      calculate_bollinger_position(snapshots)
    when /volume_ratio/
      calculate_volume_ratio(snapshots)
    else
      # 使用通用计算方法
      calculate_generic_factor(factor_def, snapshots, latest_snapshot)
    end
  end

  # 从快照计算变化率
  def calculate_change_from_snapshot(snapshot)
    return nil unless snapshot&.change_percent
    snapshot.change_percent
  end

  # 计算动量
  def calculate_momentum(snapshots, days)
    return nil if snapshots.length < days + 1
    prices = snapshots.map(&:price)
    (prices.last - prices[-(days + 1)]) / prices[-(days + 1)] * 100
  end

  # 计算波动率
  def calculate_volatility(snapshots, days)
    return nil if snapshots.length < days + 1
    prices = snapshots[-(days + 1)..-1].map(&:price)
    returns = prices.each_cons(2).map { |a, b| (b - a) / a }
    return nil if returns.empty?

    mean = returns.sum / returns.length
    variance = returns.map { |r| (r - mean)**2 }.sum / returns.length
    Math.sqrt(variance) * 100
  end

  # 计算 RSI
  def calculate_rsi(snapshots, period)
    return nil if snapshots.length < period + 1
    prices = snapshots[-(period + 1)..-1].map(&:price)

    gains = []
    losses = []

    prices.each_cons(2) do |a, b|
      change = b - a
      if change > 0
        gains << change
        losses << 0
      else
        gains << 0
        losses << change.abs
      end
    end

    avg_gain = gains.sum / period.to_f
    avg_loss = losses.sum / period.to_f

    return 100 if avg_loss == 0
    rs = avg_gain / avg_loss
    100 - (100 / (1 + rs))
  end

  # 计算布林带位置
  def calculate_bollinger_position(snapshots)
    return nil if snapshots.length < 20
    period = 20
    prices = snapshots.last(period).map(&:price)
    sma = prices.sum / period
    variance = prices.map { |p| (p - sma)**2 }.sum / period
    std_dev = Math.sqrt(variance)

    upper_band = sma + (2 * std_dev)
    lower_band = sma - (2 * std_dev)

    return 0.5 if upper_band == lower_band
    (prices.last - lower_band) / (upper_band - lower_band)
  end

  # 计算成交量比率
  def calculate_volume_ratio(snapshots)
    return nil if snapshots.length < 2
    volumes = snapshots.map(&:volume).compact
    return nil if volumes.empty?

    current_volume = volumes.last
    avg_volume = volumes[0..-2].sum / (volumes.length - 1)
    return nil if avg_volume.zero?

    current_volume / avg_volume
  end

  # 通用因子计算
  def calculate_generic_factor(factor_def, snapshots, latest_snapshot)
    # 根据 factor_def.calculation_method 和 parameters 计算
    case factor_def.calculation_method
    when "price_change"
      period = factor_def.parameter(:period) || 1
      prices = snapshots.map(&:price)
      return nil if prices.length < period + 1
      (prices.last - prices[-(period + 1)]) / prices[-(period + 1)] * 100
    when "snapshot_value"
      # 直接使用快照值
      field = factor_def.parameter(:field) || "change_percent"
      latest_snapshot&.send(field)
    else
      # 无法计算的因子返回 nil
      nil
    end
  end

  # 标准化因子值
  def normalize_factor_value(value, factor_definition)
    case factor_definition.code
    when /momentum|change/
      # 动量因子: -100 到 100 映射到 -1 到 1
      [ [ value / 100.0, 1.0 ].min, -1.0 ].max
    when /volatility/
      # 波动率: 0-100 映射到 0-1
      [ [ value / 100.0, 1.0 ].min, 0.0 ].max
    when /rsi/
      # RSI: 0-100 映射到 -1 到 1
      (value - 50) / 50.0
    when /bb_position/
      # 布林带位置: 0-1 映射到 -1 到 1
      (value - 0.5) * 2
    when /volume_ratio/
      # 成交量比率: 0-5 映射到 0-1
      [ [ value / 5.0, 1.0 ].min, 0.0 ].max
    else
      # 默认: 除以 100
      value / 100.0
    end
  end

  # 计算百分位
  def calculate_percentile(value, factor_definition)
    case factor_definition.code
    when /rsi/
      value
    when /bb_position/
      value * 100
    when /volume_ratio/
      # 成交量比率的百分位
      [ [ value * 20, 100 ].min, 0 ].max
    else
      # 使用正态分布近似
      normalized = normalize_factor_value(value, factor_definition)
      ((normalized + 1) / 2 * 100).clamp(0, 100)
    end
  end
end
