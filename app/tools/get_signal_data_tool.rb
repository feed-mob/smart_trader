# frozen_string_literal: true

# 获取交易信号工具
# 让 AI Agent 可以获取资产的交易信号，支持按信号类型、置信度筛选
class GetSignalDataTool < RubyLLM::Tool
  description "获取资产的交易信号，支持按资产、信号类型、置信度筛选"
  param :symbols, type: :array, required: false,
        desc: "资产代码数组，如 ['BTC', 'ETH']，不传则返回所有资产"
  param :signal_type, type: :string, required: false,
        desc: "信号类型: buy(买入), sell(卖出), hold(持有)"
  param :min_confidence, type: :number, required: false,
        desc: "最小置信度 0-1，如 0.7 表示只返回置信度 >= 0.7 的信号"
  param :limit, type: :integer, required: false,
        desc: "返回数量限制，默认20，最大100"

  def execute(symbols: nil, signal_type: nil, min_confidence: nil, limit: 60)
    limit = [limit.to_i, 100].min
    limit = 20 if limit <= 0

    # 构建 asset 查询
    assets = Asset.active
    assets = assets.where(symbol: symbols) if symbols.present?
    asset_ids = assets.pluck(:id)

    # 构建信号查询 - 获取每个资产的最新信号
    signals_query = TradingSignal.where(asset_id: asset_ids)
      .select("DISTINCT ON (asset_id) *")
      .order("asset_id, generated_at DESC")

    # 转换为可筛选的查询
    signals = TradingSignal.from("(#{signals_query.to_sql}) AS trading_signals")
    signals = signals.where(signal_type: signal_type) if signal_type.present?
    signals = signals.where("confidence >= ?", min_confidence) if min_confidence.present?
    signals = signals.order(confidence: :desc).limit(limit)

    # 预加载 assets
    assets_map = Asset.where(id: signals.pluck(:asset_id)).index_by(&:id)

    {
      success: true,
      count: signals.size,
      signals: signals.map do |signal|
        asset = assets_map[signal.asset_id]
        {
          symbol: asset&.symbol,
          name: asset&.name,
          signal_type: signal.signal_type,
          signal_type_label: signal.signal_type_label,
          confidence: signal.confidence&.round(3),
          confidence_level: signal.confidence_level,
          confidence_percent: signal.confidence_percentage,
          reasoning: signal.reasoning,
          generated_at: signal.generated_at&.iso8601
        }
      end
    }
  rescue StandardError => e
    { success: false, error: e.message }
  end
end
