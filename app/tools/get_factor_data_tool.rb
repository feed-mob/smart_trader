# frozen_string_literal: true

# 获取因子数据工具
# 让 AI Agent 可以获取资产的因子数据，支持按资产、因子类别筛选
class GetFactorDataTool < RubyLLM::Tool
  description "获取资产的因子数据，支持按资产、因子类别、因子代码筛选"
  param :symbols, type: :array, required: false,
        desc: "资产代码数组，如 ['BTC', 'ETH']，不传则返回所有资产"
  param :category, type: :string, required: false,
        desc: "因子类别: technical, fundamental, sentiment, momentum, risk, volume"
  param :factor_codes, type: :array, required: false,
        desc: "因子代码数组，如 ['rsi_14', 'macd', 'volatility']"
  param :min_percentile, type: :number, required: false,
        desc: "最小百分位筛选，0-100，如 70 表示只返回百分位 >= 70 的因子"
  param :max_percentile, type: :number, required: false,
        desc: "最大百分位筛选，0-100"

  def execute(symbols: nil, category: nil, factor_codes: nil, min_percentile: nil, max_percentile: nil)
    # 构建 asset 查询
    assets = Asset.active
    assets = assets.where(symbol: symbols) if symbols.present?
    asset_ids = assets.pluck(:id)

    # 构建 factor_values 查询
    factor_values = FactorValue.where(asset_id: asset_ids).latest
    factor_values = factor_values.joins(:factor_definition)
    factor_values = factor_values.where(factor_definitions: { category: category }) if category.present?
    factor_values = factor_values.where(factor_definitions: { code: factor_codes }) if factor_codes.present?
    factor_values = factor_values.where("factor_values.percentile >= ?", min_percentile) if min_percentile.present?
    factor_values = factor_values.where("factor_values.percentile <= ?", max_percentile) if max_percentile.present?

    # 按资产分组
    assets_map = Asset.where(id: asset_ids).index_by(&:id)
    results = factor_values.group_by(&:asset_id).map do |asset_id, values|
      asset = assets_map[asset_id]
      {
        symbol: asset&.symbol,
        name: asset&.name,
        factors: values.map do |factor_value|
          factor_def = factor_value.factor_definition
          {
            code: factor_def.code,
            name: factor_def.name,
            category: factor_def.category,
            display_category: factor_def.display_category,
            value: factor_value.normalized_value&.round(4),
            percentile: factor_value.percentile&.round(1),
            raw_value: factor_value.raw_value&.round(4),
            calculated_at: factor_value.calculated_at&.iso8601
          }
        end.sort_by { |f| [f[:category], f[:code]] }
      }
    end

    {
      success: true,
      count: results.sum { |r| r[:factors].size },
      assets_count: results.size,
      data: results
    }
  rescue StandardError => e
    { success: false, error: e.message }
  end
end
