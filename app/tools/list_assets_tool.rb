# frozen_string_literal: true

# 获取资产列表工具
# 让 AI Agent 可以获取可用资产列表，支持按类型筛选
class ListAssetsTool < RubyLLM::Tool
  description "获取可用资产列表，支持按类型筛选"
  param :asset_type, type: :string, required: false,
        desc: "资产类型: crypto(加密货币), stock(股票), etf(ETF基金)"
  param :limit, type: :integer, required: false,
        desc: "返回数量限制，默认20，最大100"

  def execute(asset_type: nil, limit: 60)
    limit = [limit.to_i, 100].min
    limit = 20 if limit <= 0

    assets = Asset.active
    assets = assets.by_type(asset_type) if asset_type.present?
    assets = assets.limit(limit)

    {
      success: true,
      count: assets.count,
      assets: assets.map do |asset|
        {
          symbol: asset.symbol,
          name: asset.name,
          asset_type: asset.asset_type,
          exchange: asset.exchange,
          quote_currency: asset.quote_currency,
          trading_pair: asset.trading_pair
        }
      end
    }
  rescue StandardError => e
    { success: false, error: e.message }
  end
end
