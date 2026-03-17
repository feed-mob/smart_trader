# frozen_string_literal: true

class AllocationExecutionService
  def initialize(allocation_decision, run_at: Time.current)
    @allocation_decision = allocation_decision
    @trader = allocation_decision.trader
    @run_at = run_at
    @recommendation = allocation_decision.recommendation_payload_symbolized
    @latest_prices = {}
  end

  def call
    @task = @trader.allocation_tasks.create!(
      allocation_decision: @allocation_decision,
      run_on: @run_at.to_date,
      status: :running,
      started_at: @run_at,
      summary: "开始执行 allocation decision ##{@allocation_decision.id}"
    )

    ActiveRecord::Base.transaction do
      strategy = find_strategy!
      allocations = normalized_allocations
      validate_execution!(strategy, allocations)

      existing_positions = refresh_existing_positions
      starting_invested_value = existing_positions.sum { |position| position.market_value.to_d }
      total_equity = [@trader.current_capital_value.to_d, starting_invested_value].max
      starting_cash = [total_equity - starting_invested_value, 0.to_d].max.round(2)

      updates = apply_target_allocations!(allocations, existing_positions, total_equity)
      updates.concat(deactivate_non_target_positions!(allocations, existing_positions))
      persist_trades!(updates)

      ending_invested_value = @trader.trader_positions.active.sum(:market_value).to_d.round(2)
      ending_cash = [total_equity - ending_invested_value, 0.to_d].max.round(2)
      portfolio_value = (ending_cash + ending_invested_value).round(2)

      @trader.update!(current_capital: portfolio_value)

      @task.update!(
        status: :completed,
        starting_cash: starting_cash,
        ending_cash: ending_cash,
        portfolio_value: portfolio_value,
        summary: build_summary(updates, portfolio_value),
        execution_payload: build_execution_payload(strategy, allocations, updates, starting_cash, ending_cash),
        completed_at: Time.current
      )

      create_portfolio_snapshot!(
        cash_value: ending_cash,
        invested_value: ending_invested_value,
        portfolio_value: portfolio_value
      )
    end

    @task
  rescue StandardError => e
    Rails.logger.error("[AllocationExecutionService] decision=#{@allocation_decision.id} failed: #{e.message}")
    @task&.update(
      status: :failed,
      error_message: e.message,
      summary: "执行失败: #{e.message}",
      completed_at: Time.current
    )
    raise
  end

  private

  def find_strategy!
    @allocation_decision.trading_strategy || @trader.strategy_for(@recommendation[:selected_strategy]).tap do |strategy|
      raise "No trading strategy found for recommendation" if strategy.blank?
    end
  end

  def normalized_allocations
    Array(@recommendation[:allocations]).map do |allocation|
      allocation.deep_symbolize_keys
    end
  end

  def validate_execution!(strategy, allocations)
    raise "Recommendation payload is missing cash_reserve" unless @recommendation[:cash_reserve].is_a?(Hash)
    raise "Allocations exceed strategy max_positions" if allocations.size > strategy.max_positions

    cash_percent = @recommendation.dig(:cash_reserve, :percent).to_f
    total_percent = allocations.sum { |allocation| allocation[:allocation_percent].to_f } + cash_percent
    raise "Allocation percentages must sum to 100" unless total_percent.round(2) == 100.0

    allocations.each do |allocation|
      symbol = allocation[:symbol].to_s.upcase
      asset = Asset.active.find_by(symbol: symbol)
      raise "Asset not found for symbol #{symbol}" if asset.blank?

      allocation_percent = allocation[:allocation_percent].to_d / 100
      raise "Allocation #{symbol} exceeds max_position_size" if allocation_percent > strategy.max_position_size.to_d

      price = asset.latest_snapshot&.price&.to_d
      raise "Latest price missing for asset #{symbol}" if price.blank? || price <= 0

      @latest_prices[asset.id] = price
    end
  end

  def refresh_existing_positions
    @trader.trader_positions.includes(:asset).map do |position|
      price = position.asset.latest_snapshot&.price&.to_d || position.current_price.to_d
      next position if price <= 0

      update_position_metrics!(position, quantity: position.quantity.to_d, average_cost: position.average_cost.to_d, price: price)
      position
    end.compact
  end

  def apply_target_allocations!(allocations, existing_positions, total_equity)
    positions_by_asset_id = existing_positions.index_by(&:asset_id)
    updates = []

    allocations.each do |allocation|
      asset = Asset.active.find_by!(symbol: allocation[:symbol].to_s.upcase)
      price = @latest_prices[asset.id] || asset.latest_snapshot&.price&.to_d
      target_percent = allocation[:allocation_percent].to_d / 100
      target_value = (total_equity * target_percent).round(2)
      target_quantity = price.positive? ? (target_value / price).round(8) : 0.to_d

      position = positions_by_asset_id[asset.id] || @trader.trader_positions.find_or_initialize_by(asset: asset)
      previous_quantity = position.quantity.to_d
      previous_value = position.market_value.to_d

      average_cost = next_average_cost(position, target_quantity, price)
      update_position_metrics!(
        position,
        quantity: target_quantity,
        average_cost: average_cost,
        price: price,
        active: target_quantity.positive?,
        opened_at: position.opened_at || @run_at,
        last_rebalanced_at: @run_at
      )

      updates << {
        symbol: asset.symbol,
        asset_id: asset.id,
        previous_quantity: previous_quantity.to_f,
        target_quantity: target_quantity.to_f,
        previous_value: previous_value.to_f,
        target_value: target_value.to_f,
        action: action_for(previous_quantity, target_quantity),
        reason: allocation[:reason],
        trade_quantity: (target_quantity - previous_quantity).abs.to_f,
        trade_price: price.to_f,
        trade_amount: (target_value - previous_value).abs.to_f
      }
    end

    updates
  end

  def deactivate_non_target_positions!(allocations, existing_positions)
    target_symbols = allocations.map { |allocation| allocation[:symbol].to_s.upcase }
    updates = []

    existing_positions.each do |position|
      next if target_symbols.include?(position.asset.symbol.upcase)

      price = position.asset.latest_snapshot&.price&.to_d || position.current_price.to_d
      previous_quantity = position.quantity.to_d
      previous_value = position.market_value.to_d
      update_position_metrics!(
        position,
        quantity: 0,
        average_cost: position.average_cost.to_d,
        price: price,
        active: false,
        last_rebalanced_at: @run_at
      )

      updates << {
        symbol: position.asset.symbol,
        asset_id: position.asset_id,
        previous_quantity: previous_quantity.to_f,
        target_quantity: 0.0,
        previous_value: previous_value.to_f,
        target_value: 0.0,
        action: "sell",
        reason: "资产不在最新 recommendation 目标组合中",
        trade_quantity: previous_quantity.to_f,
        trade_price: price.to_f,
        trade_amount: previous_value.to_f
      }
    end

    updates
  end

  def next_average_cost(position, target_quantity, current_price)
    previous_quantity = position.quantity.to_d
    previous_average_cost = position.average_cost.to_d
    return current_price.round(2) if previous_quantity.zero? && target_quantity.positive?
    return previous_average_cost if target_quantity <= previous_quantity

    additional_quantity = target_quantity - previous_quantity
    total_cost = (previous_quantity * previous_average_cost) + (additional_quantity * current_price)
    (total_cost / target_quantity).round(2)
  end

  def update_position_metrics!(position, quantity:, average_cost:, price:, active: nil, opened_at: position.opened_at, last_rebalanced_at: position.last_rebalanced_at)
    quantity = quantity.to_d
    price = price.to_d
    market_value = (quantity * price).round(2)
    cost_basis = (quantity * average_cost.to_d).round(2)
    pnl = (market_value - cost_basis).round(2)
    pnl_percent = cost_basis.positive? ? ((pnl / cost_basis) * 100).round(2) : 0

    position.assign_attributes(
      quantity: quantity,
      average_cost: average_cost,
      current_price: price,
      market_value: market_value,
      unrealized_pnl: pnl,
      unrealized_pnl_percent: pnl_percent,
      active: active.nil? ? quantity.positive? : active,
      opened_at: opened_at,
      last_rebalanced_at: last_rebalanced_at
    )
    position.save!
  end

  def build_summary(updates, portfolio_value)
    "执行 #{updates.size} 个目标仓位更新，最新组合净值 #{portfolio_value.to_f.round(2)}。"
  end

  def build_execution_payload(strategy, allocations, updates, starting_cash, ending_cash)
    {
      decision_id: @allocation_decision.id,
      strategy: {
        id: strategy.id,
        name: strategy.name,
        selected_strategy: @allocation_decision.selected_strategy,
        max_positions: strategy.max_positions,
        max_position_size: strategy.max_position_size.to_f
      },
      cash_reserve: @recommendation[:cash_reserve],
      starting_cash: starting_cash.to_f,
      ending_cash: ending_cash.to_f,
      allocations: allocations.map(&:deep_stringify_keys),
      updates: updates
    }
  end

  def create_portfolio_snapshot!(cash_value:, invested_value:, portfolio_value:)
    profit_loss = (portfolio_value.to_d - @trader.initial_capital.to_d).round(2)
    profit_loss_percent = if @trader.initial_capital.to_d.positive?
                            ((profit_loss / @trader.initial_capital.to_d) * 100).round(2)
                          else
                            0
                          end

    @trader.portfolio_snapshots.create!(
      allocation_task: @task,
      snapshot_date: @run_at.to_date,
      captured_at: @run_at,
      cash_value: cash_value,
      invested_value: invested_value,
      portfolio_value: portfolio_value,
      profit_loss: profit_loss,
      profit_loss_percent: profit_loss_percent,
      source: "execution",
      metadata: {
        allocation_decision_id: @allocation_decision.id,
        allocation_task_id: @task.id
      }
    )
  end

  def persist_trades!(updates)
    updates.each do |update|
      next if update[:action] == "hold"
      next if update[:trade_quantity].to_d <= 0 || update[:trade_amount].to_d <= 0

      @trader.trader_trades.create!(
        allocation_task: @task,
        allocation_decision: @allocation_decision,
        asset_id: update[:asset_id],
        action: update[:action],
        quantity: update[:trade_quantity],
        price: update[:trade_price],
        amount: update[:trade_amount],
        reason: update[:reason],
        executed_at: @run_at
      )
    end
  end

  def action_for(previous_quantity, target_quantity)
    return "buy" if previous_quantity.zero? && target_quantity.positive?
    return "sell" if previous_quantity.positive? && target_quantity.zero?
    return "buy" if target_quantity > previous_quantity
    return "sell" if target_quantity < previous_quantity

    "hold"
  end
end
