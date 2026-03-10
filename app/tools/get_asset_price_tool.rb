# frozen_string_literal: true

# 获取资产价格工具
# 让 AI Agent 可以获取资产的最新价格信息
class GetAssetPriceTool < RubyLLM::Tool
  description "获取资产最新价格信息，支持按 symbol 查询单个或多个资产"
  param :symbols, type: :array, required: true,
        desc: "资产代码数组，如 ['BTC', 'ETH', 'AAPL']"
  param :exchange, type: :string, required: false,
        desc: "交易所名称，用于区分同 symbol 的不同资产"

  def execute(symbols:, exchange: nil)
    return { success: false, error: "symbols 不能为空" } if symbols.blank?

    assets = Asset.where(symbol: symbols, active: true)
    assets = assets.where(exchange: exchange) if exchange.present?

    asset_ids = assets.pluck(:id)
    snapshots = AssetSnapshot
      .where(asset_id: asset_ids)
      .select("DISTINCT ON (asset_id) *")
      .order("asset_id, captured_at DESC")
      .index_by(&:asset_id)

    {
      success: true,
      prices: assets.map do |asset|
        snapshot = snapshots[asset.id]
        {
          symbol: asset.symbol,
          name: asset.name,
          exchange: asset.exchange,
          price: snapshot&.price,
          change_percent: snapshot&.change_percent,
          volume: snapshot&.volume,
          captured_at: snapshot&.captured_at&.iso8601
        }
      end
    }
  rescue StandardError => e
    { success: false, error: e.message }
  end
end
