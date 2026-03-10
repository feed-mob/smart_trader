# frozen_string_literal: true

# 获取操盘手信息工具
# 让 AI Agent 可以获取当前操盘手的策略配置和资金信息
class TraderInfoTool < RubyLLM::Tool
  description "获取当前操盘手的详细信息，包括策略配置、资金状况"
  param :trader_id, type: :integer, required: true,
        desc: "操盘手 ID"
  param :include_strategies, type: :boolean, required: false,
        desc: "是否包含策略配置，默认 true"

  def execute(trader_id:, include_strategies: true)
    trader = Trader.find_by(id: trader_id)
    return { success: false, error: "操盘手不存在，ID: #{trader_id}" } unless trader

    result = {
      success: true,
      trader: {
        id: trader.id,
        name: trader.name,
        description: trader.description,
        risk_level: trader.risk_level,
        display_risk_level: trader.display_risk_level,
        initial_capital: trader.initial_capital,
        current_capital: trader.current_capital_value,
        status: trader.status
      }
    }

    if include_strategies
      strategies = trader.trading_strategies.order(:market_condition)
      result[:strategies] = strategies.map do |strategy|
        {
          market_condition: strategy.market_condition,
          display_market_condition: strategy.display_market_condition,
          risk_level: strategy.risk_level,
          max_positions: strategy.max_positions,
          buy_signal_threshold: strategy.buy_signal_threshold,
          buy_signal_threshold_percent: (strategy.buy_signal_threshold * 100).round(0),
          max_position_size: strategy.max_position_size,
          max_position_size_percent: (strategy.max_position_size * 100).round(0),
          min_cash_reserve: strategy.min_cash_reserve,
          min_cash_reserve_percent: (strategy.min_cash_reserve * 100).round(0),
          name: strategy.name,
          description: strategy.description
        }
      end
    end

    result
  rescue StandardError => e
    { success: false, error: e.message }
  end
end
