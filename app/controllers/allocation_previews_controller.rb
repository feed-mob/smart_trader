# frozen_string_literal: true

class AllocationPreviewsController < ApplicationController
  before_action :require_user
  before_action :set_trader

  def show
    # 预加载非 AI 数据
    @preview = build_base_preview
  end

  # 异步加载 AI 配置建议 (缓存1分钟)
  def recommendation
    @recommendation = Rails.cache.fetch(cache_key_for_recommendation, expires_in: 2.minute) do
      AiAllocationService.new(@trader).generate_recommendation
    end
    @strategies = @trader.trading_strategies.order(:market_condition)

    render partial: "recommendation", locals: { recommendation: @recommendation, strategies: @strategies }
  end

  private

  def set_trader
    @trader = Trader.find(params[:trader_id])
  end

  def cache_key_for_recommendation
    "trader/#{@trader.id}/allocation_recommendation"
  end

  def cache_key_for_recommendation
    "trader/#{@trader.id}/allocation_recommendation"
  end

  # 构建基础预览数据（不含 AI 建议）
  def build_base_preview
    assets_data = collect_asset_data

    {
      trader: trader_info,
      strategies: strategies_info,
      signals: extract_signals(assets_data),
      factors: extract_factors(assets_data),
      assets: assets_data
    }
  end

  def collect_asset_data
    Asset.all.map do |asset|
      snapshot = asset.latest_snapshot
      factor_values = collect_factor_values(asset)
      signal = collect_latest_signal(asset)

      {
        symbol: asset.symbol,
        name: asset.name,
        asset_type: asset.asset_type,
        price: snapshot&.price,
        signal: signal&.signal_type,
        confidence: signal&.confidence,
        reasoning: signal&.reasoning,
        factors: factor_values
      }
    end
  end

  def collect_factor_values(asset)
    FactorValue.where(asset: asset).latest
      .joins(:factor_definition)
      .pluck(
        "factor_definitions.code",
        "factor_definitions.name",
        "factor_definitions.category",
        "factor_values.normalized_value",
        "factor_values.percentile"
      ).map do |code, name, category, normalized_value, percentile|
        {
          code: code,
          name: name,
          category: category,
          value: normalized_value&.round(2),
          percentile: percentile&.round(1)
        }
      end
  end

  def collect_latest_signal(asset)
    TradingSignal.where(asset: asset).order(generated_at: :desc).first
  end

  def trader_info
    {
      id: @trader.id,
      name: @trader.name,
      risk_level: @trader.risk_level,
      display_risk_level: @trader.display_risk_level,
      initial_capital: @trader.initial_capital,
      current_capital: @trader.current_capital_value
    }
  end

  def strategies_info
    @trader.trading_strategies.order(:market_condition).map do |strategy|
      {
        market_condition: strategy.market_condition,
        display_market_condition: strategy.display_market_condition,
        risk_level: strategy.risk_level,
        max_positions: strategy.max_positions,
        buy_signal_threshold: strategy.buy_signal_threshold,
        max_position_size: strategy.max_position_size,
        min_cash_reserve: strategy.min_cash_reserve,
        name: strategy.name,
        description: strategy.description
      }
    end
  end

  def extract_signals(assets_data)
    assets_data.filter_map do |data|
      next if data[:signal].blank?

      {
        symbol: data[:symbol],
        name: data[:name],
        signal_type: data[:signal],
        confidence: data[:confidence],
        reasoning: data[:reasoning]
      }
    end
  end

  def extract_factors(assets_data)
    assets_data.map do |data|
      {
        symbol: data[:symbol],
        name: data[:name],
        factors: data[:factors]
      }
    end
  end
end
