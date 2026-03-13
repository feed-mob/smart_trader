# frozen_string_literal: true

class MarkToMarketPortfolioSnapshotService
  def initialize(run_at: Time.current, scope: Trader.active, force: false)
    @run_at = run_at
    @scope = scope
    @force = force
  end

  def call
    results = { created: 0, skipped: 0, failed: 0 }

    @scope.includes(trader_positions: :asset, allocation_tasks: []).find_each do |trader|
      outcome = create_snapshot_for_trader!(trader)
      results[outcome] += 1
    rescue StandardError => e
      trader_id = trader&.id || "unknown"
      Rails.logger.error("[MarkToMarketPortfolioSnapshotService] failed trader=#{trader_id}: #{e.message}")
      results[:failed] += 1
    end

    results
  end

  private

  def create_snapshot_for_trader!(trader)
    if !@force && snapshot_exists_for?(trader)
      Rails.logger.info("[MarkToMarketPortfolioSnapshotService] skipped trader=#{trader.id} date=#{@run_at.to_date} reason=already_snapshotted")
      return :skipped
    end

    active_positions = trader.trader_positions.active.includes(:asset)
    invested_value = active_positions.sum do |position|
      position.quantity.to_d * price_for_snapshot(position)
    end.round(2)

    latest_completed_task = latest_completed_task_for(trader)
    cash_value = if latest_completed_task.present?
                   latest_completed_task.ending_cash.to_d.round(2)
                 else
                   [trader.current_capital_value.to_d - invested_value, 0.to_d].max.round(2)
                 end

    portfolio_value = (cash_value + invested_value).round(2)
    profit_loss = (portfolio_value - trader.initial_capital.to_d).round(2)
    profit_loss_percent = if trader.initial_capital.to_d.positive?
                            ((profit_loss / trader.initial_capital.to_d) * 100).round(2)
                          else
                            0
                          end

    trader.portfolio_snapshots.create!(
      snapshot_date: @run_at.to_date,
      captured_at: @run_at,
      cash_value: cash_value,
      invested_value: invested_value,
      portfolio_value: portfolio_value,
      profit_loss: profit_loss,
      profit_loss_percent: profit_loss_percent,
      source: "mark_to_market",
      metadata: {
        latest_allocation_task_id: latest_completed_task&.id,
        position_count: active_positions.size
      }
    )

    trader.update!(current_capital: portfolio_value)

    :created
  end

  def snapshot_exists_for?(trader)
    trader.portfolio_snapshots.exists?(snapshot_date: @run_at.to_date, source: "mark_to_market")
  end

  def latest_completed_task_for(trader)
    trader.allocation_tasks
      .completed
      .where("completed_at <= ? OR (completed_at IS NULL AND run_on <= ?)", @run_at, @run_at.to_date)
      .order(run_on: :desc, created_at: :desc)
      .first
  end

  def price_for_snapshot(position)
    historical_snapshot = position.asset.asset_snapshots
      .where("captured_at <= ?", @run_at)
      .order(captured_at: :desc)
      .first

    historical_snapshot&.price&.to_d || position.current_price.to_d
  end
end
