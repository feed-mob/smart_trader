# frozen_string_literal: true

class TradersController < ApplicationController
  before_action :require_user
  before_action :set_trader, only: %i[show edit update destroy]

  def index
    @traders = Trader.ordered_by_created
  end

  def show
    @strategies = @trader.trading_strategies.order(:market_condition)
  end

  def new
    @trader = Trader.new(initial_capital: 100_000)
  end

  def edit; end

  def create
    @trader = Trader.new(trader_params)

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
end
