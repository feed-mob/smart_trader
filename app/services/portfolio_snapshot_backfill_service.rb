# frozen_string_literal: true

class PortfolioSnapshotBackfillService
  def initialize(scope: AllocationTask.completed.includes(:trader, :portfolio_snapshot))
    @scope = scope
  end

  def call
    results = { created: 0, skipped: 0 }

    @scope.find_each do |task|
      if task.portfolio_snapshot.present?
        results[:skipped] += 1
        next
      end

      trader = task.trader
      profit_loss = (task.portfolio_value.to_d - trader.initial_capital.to_d).round(2)
      profit_loss_percent = if trader.initial_capital.to_d.positive?
                              ((profit_loss / trader.initial_capital.to_d) * 100).round(2)
                            else
                              0
                            end

      trader.portfolio_snapshots.create!(
        allocation_task: task,
        snapshot_date: task.run_on,
        captured_at: task.completed_at || task.created_at,
        cash_value: task.ending_cash,
        invested_value: (task.portfolio_value.to_d - task.ending_cash.to_d).round(2),
        portfolio_value: task.portfolio_value,
        profit_loss: profit_loss,
        profit_loss_percent: profit_loss_percent,
        source: "execution",
        metadata: {
          allocation_decision_id: task.allocation_decision_id,
          backfilled_from_task: true
        }
      )

      results[:created] += 1
    end

    results
  end
end
