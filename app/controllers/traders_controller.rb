# frozen_string_literal: true

class TradersController < ApplicationController
  before_action :require_user
  before_action :set_trader, only: %i[show edit update destroy]

  def index
    @traders = Trader.ordered_by_created
  end

  def show
    @strategies = @trader.trading_strategies.order(:market_condition)
    @latest_allocation_task = @trader.allocation_tasks.recent.first
    @latest_portfolio_snapshot = @trader.portfolio_snapshots.recent.first
    @trader_positions = @trader.trader_positions.active.includes(:asset).ordered_by_value
    @trader_position_rows = build_trader_position_rows(@trader_positions)
    @recent_trader_trades = @trader.trader_trades.recent.includes(:asset).limit(10)
    @latest_trader_reflection = @trader.trader_reflections.recent.first
  end

  def new
    @trader = Trader.new(initial_capital: 100_000)
  end

  def edit; end

  def create
    @trader = Trader.new(trader_params)
    @trader.user = current_user

    if @trader.save
      generate_strategies_for(@trader)
      redirect_to @trader, notice: "操盘手创建成功"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @trader.update(trader_params)
      regenerate_strategies_if_needed(@trader)
      redirect_to @trader, notice: "操盘手更新成功"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @trader.destroy
    redirect_to traders_url, notice: "操盘手已删除"
  end

  private

  def set_trader
    @trader = Trader.find(params[:id])
  end

  def trader_params
    params.require(:trader).permit(:name, :risk_level, :initial_capital, :status, :description)
  end

  def generate_strategies_for(trader)
    service = StrategyGeneratorService.new(trader.description, risk_level: trader.risk_level)
    strategies = service.generate_strategies

    strategies.each do |strategy_params|
      trader.trading_strategies.create(strategy_params)
    end
  end

  def regenerate_strategies_if_needed(trader)
    return unless trader.saved_change_to_description? || trader.saved_change_to_risk_level?

    trader.trading_strategies.destroy_all
    generate_strategies_for(trader)
  end

  def build_trader_position_rows(positions)
    positions.map do |position|
      quantity = position.quantity.to_d
      latest_price = position.asset.latest_snapshot&.price&.to_d || position.current_price.to_d
      market_value = (quantity * latest_price).round(2)
      cost_basis = (quantity * position.average_cost.to_d).round(2)
      unrealized_pnl = (market_value - cost_basis).round(2)
      unrealized_pnl_percent = if cost_basis.positive?
                                 ((unrealized_pnl / cost_basis) * 100).round(2)
                               else
                                 0
                               end

      {
        position: position,
        latest_price: latest_price,
        market_value: market_value,
        unrealized_pnl: unrealized_pnl,
        unrealized_pnl_percent: unrealized_pnl_percent
      }
    end
  end
end
