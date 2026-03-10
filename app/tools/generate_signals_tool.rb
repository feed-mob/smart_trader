# frozen_string_literal: true

# 信号生成工具
# 让 AI Agent 可以基于因子数据为资产生成交易信号（只读查询，不保存）
class GenerateSignalsTool < RubyLLM::Tool
  description "基于因子数据为资产生成交易信号（买入/卖出/持有），仅返回结果不保存"
  param :symbols, type: :array, required: false,
        desc: "资产代码数组，如 ['BTCUSDT', 'ETHUSDT']，不传则处理所有资产"
  param :use_cache, type: :boolean, required: false,
        desc: "是否使用缓存的信号（1小时内），默认 true"

  def execute(symbols: nil, use_cache: true)
    # 获取资产
    assets = Asset.active
    assets = assets.where(symbol: symbols) if symbols.present?
    assets = assets.limit(50).to_a

    return { success: false, error: "未找到匹配的资产" } if assets.empty?

    # 生成信号
    signals_count = { buy: 0, sell: 0, hold: 0 }
    results = []

    assets.each do |asset|
      signal_data = generate_signal_for_asset(asset, use_cache)
      signals_count[signal_data[:type].to_sym] += 1
      results << signal_data
    end

    {
      success: true,
      assets_processed: assets.size,
      signals_summary: signals_count,
      results: results
    }
  rescue StandardError => e
    { success: false, error: e.message, backtrace: e.backtrace&.first(5) }
  end

  private

  # 为单个资产生成信号（只读）
  def generate_signal_for_asset(asset, use_cache)
    # 尝试从缓存获取
    if use_cache
      existing = TradingSignal.where(asset: asset)
        .where("generated_at > ?", 1.hour.ago)
        .order(generated_at: :desc)
        .first

      if existing
        return {
          symbol: asset.symbol,
          name: asset.name,
          signal_type: existing.signal_type,
          confidence: existing.confidence&.round(3),
          reasoning: existing.reasoning,
          source: "cache"
        }
      end
    end

    # 获取最新的因子值
    factor_values = FactorValue.where(asset: asset)
      .where("calculated_at > ?", 1.hour.ago)
      .includes(:factor_definition)
      .index_by { |fv| fv.factor_definition.code }

    # 基于因子生成信号
    signal_data = calculate_signal_from_factors(asset, factor_values)
    signal_data[:source] = "calculated"
    signal_data
  end

  # 基于因子计算信号
  def calculate_signal_from_factors(asset, factor_values)
    # 获取各类因子值
    momentum_7d = factor_values["momentum_7d"]&.raw_value ||
                  factor_values["momentum_7"]&.raw_value || 0
    momentum_30d = factor_values["momentum_30d"]&.raw_value ||
                   factor_values["momentum_30"]&.raw_value
    rsi = factor_values["rsi_14"]&.raw_value ||
          factor_values["rsi"]&.raw_value || 50
    bb_position = factor_values["bb_position"]&.raw_value ||
                  factor_values["bollinger_position"]&.raw_value || 0.5
    change_15m = factor_values["change_15m"]&.raw_value ||
                 factor_values["momentum_15m"]&.raw_value || 0
    volatility = factor_values["volatility_7d"]&.raw_value ||
                 factor_values["volatility"]&.raw_value || 0
    volume_ratio = factor_values["volume_ratio"]&.raw_value || 1

    # 信号评分
    buy_score = 0
    sell_score = 0
    reasons = []

    # 动量因子 (7日)
    if momentum_7d > 15
      buy_score += 2
      reasons << "7日动量强劲(+#{momentum_7d.round(1)}%)"
    elsif momentum_7d > 5
      buy_score += 1
      reasons << "7日动量偏强(+#{momentum_7d.round(1)}%)"
    elsif momentum_7d < -15
      sell_score += 2
      reasons << "7日动量疲软(#{momentum_7d.round(1)}%)"
    elsif momentum_7d < -5
      sell_score += 1
      reasons << "7日动量偏弱(#{momentum_7d.round(1)}%)"
    end

    # 动量因子 (30日)
    if momentum_30d
      if momentum_30d > 30
        buy_score += 1
        reasons << "30日趋势向上(+#{momentum_30d.round(1)}%)"
      elsif momentum_30d < -30
        sell_score += 1
        reasons << "30日趋势向下(#{momentum_30d.round(1)}%)"
      end
    end

    # RSI 因子
    if rsi < 25
      buy_score += 3
      reasons << "RSI严重超卖(#{rsi.round(1)})"
    elsif rsi < 35
      buy_score += 2
      reasons << "RSI超卖(#{rsi.round(1)})"
    elsif rsi > 75
      sell_score += 3
      reasons << "RSI严重超买(#{rsi.round(1)})"
    elsif rsi > 65
      sell_score += 2
      reasons << "RSI超买(#{rsi.round(1)})"
    end

    # 布林带位置
    if bb_position < 0.15
      buy_score += 2
      reasons << "价格触及布林带下轨"
    elsif bb_position < 0.25
      buy_score += 1
      reasons << "价格接近布林带下轨"
    elsif bb_position > 0.85
      sell_score += 2
      reasons << "价格触及布林带上轨"
    elsif bb_position > 0.75
      sell_score += 1
      reasons << "价格接近布林带上轨"
    end

    # 15分钟变化（短期动量）
    if change_15m > 3
      buy_score += 1
      reasons << "短期上涨动能(+#{change_15m.round(2)}%)"
    elsif change_15m < -3
      sell_score += 1
      reasons << "短期下跌压力(#{change_15m.round(2)}%)"
    end

    # 波动率调整（高波动时降低置信度）
    volatility_penalty = volatility > 50 ? 0.15 : (volatility > 30 ? 0.05 : 0)

    # 成交量确认
    volume_bonus = volume_ratio > 2 ? 0.5 : (volume_ratio > 1.5 ? 0.25 : 0)

    # 确定信号类型和置信度
    if buy_score >= 3 && buy_score > sell_score
      confidence = [ (buy_score / 8.0 + volume_bonus - volatility_penalty), 0.95 ].min
      confidence = [ confidence, 0.3 ].max
      {
        symbol: asset.symbol,
        name: asset.name,
        signal_type: "buy",
        confidence: confidence.round(3),
        reasoning: "买入信号: #{reasons.join('; ')}"
      }
    elsif sell_score >= 3 && sell_score > buy_score
      confidence = [ (sell_score / 8.0 + volume_bonus - volatility_penalty), 0.95 ].min
      confidence = [ confidence, 0.3 ].max
      {
        symbol: asset.symbol,
        name: asset.name,
        signal_type: "sell",
        confidence: confidence.round(3),
        reasoning: "卖出信号: #{reasons.join('; ')}"
      }
    else
      # 持有信号
      confidence = 0.5
      reasoning_text = if reasons.empty?
        "持有观望: 多空信号均衡"
      else
        "持有观望: #{reasons.join('; ')}"
      end

      {
        symbol: asset.symbol,
        name: asset.name,
        signal_type: "hold",
        confidence: confidence,
        reasoning: reasoning_text
      }
    end
  end
end
