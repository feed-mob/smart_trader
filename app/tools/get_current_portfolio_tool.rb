# frozen_string_literal: true

# 获取当前组合上下文工具
# 让 AI Agent 在生成 recommendation 前读取当前现金、持仓和最近执行摘要
class GetCurrentPortfolioTool < RubyLLM::Tool
  description "获取操盘手当前组合上下文，包括现金、持仓、仓位占比、浮盈亏和最近执行摘要"
  param :trader_id, type: :integer, required: true,
        desc: "操盘手 ID"

  def execute(trader_id:)
    trader = Trader.find_by(id: trader_id)
    return { success: false, error: "操盘手不存在，ID: #{trader_id}" } unless trader

    positions = trader.trader_positions.active.includes(:asset).ordered_by_value
    latest_task = trader.allocation_tasks.recent.first
    total_equity = trader.current_capital_value.to_d
    invested_value = positions.sum(&:market_value).to_d
    cash_value = if latest_task.present?
                   latest_task.ending_cash.to_d
                 else
                   [total_equity - invested_value, 0.to_d].max
                 end

    {
      success: true,
      portfolio: {
        trader_id: trader.id,
        total_equity: total_equity.to_f,
        cash_value: cash_value.round(2).to_f,
        invested_value: invested_value.round(2).to_f,
        latest_task: latest_task_payload(latest_task),
        positions: positions.map do |position|
          {
            symbol: position.asset.symbol,
            asset_name: position.asset.name,
            quantity: position.quantity.to_d.round(8).to_f,
            average_cost: position.average_cost.to_d.round(2).to_f,
            current_price: position.current_price.to_d.round(2).to_f,
            market_value: position.market_value.to_d.round(2).to_f,
            allocation_percent: allocation_percent(position.market_value.to_d, total_equity),
            unrealized_pnl: position.unrealized_pnl.to_d.round(2).to_f,
            unrealized_pnl_percent: position.unrealized_pnl_percent.to_d.round(2).to_f,
            last_rebalanced_at: position.last_rebalanced_at&.iso8601
          }
        end
      }
    }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  private

  def latest_task_payload(task)
    return nil unless task

    {
      id: task.id,
      run_on: task.run_on,
      status: task.status,
      summary: task.summary,
      ending_cash: task.ending_cash.to_d.round(2).to_f,
      portfolio_value: task.portfolio_value.to_d.round(2).to_f,
      completed_at: task.completed_at&.iso8601
    }
  end

  def allocation_percent(market_value, total_equity)
    return 0.0 unless total_equity.positive?

    ((market_value / total_equity) * 100).round(2).to_f
  end
end
