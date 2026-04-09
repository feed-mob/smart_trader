# frozen_string_literal: true

class TraderReflectionsController < ApplicationController
  before_action :require_user
  before_action :set_trader
  before_action :set_trader_reflection, only: %i[show apply_adjustment]

  def create
    reflection = TraderReflectionService.new(@trader).call
    redirect_to trader_trader_reflection_path(@trader, reflection), notice: "Reflection report generated successfully"
  rescue StandardError => e
    redirect_to trader_path(@trader), alert: "Failed to generate reflection report: #{e.message}"
  end

  def show; end

  def apply_adjustment
    ApplyTraderReflectionAdjustmentService.new(
      @trader_reflection,
      parameter: params[:parameter]
    ).call

    redirect_to trader_trader_reflection_path(@trader, @trader_reflection), notice: "Strategy parameters applied to current strategy"
  rescue StandardError => e
    redirect_to trader_trader_reflection_path(@trader, @trader_reflection), alert: "Failed to apply suggestion: #{e.message}"
  end

  private

  def set_trader
    @trader = Trader.find(params[:trader_id])
  end

  def set_trader_reflection
    @trader_reflection = @trader.trader_reflections.find(params[:id])
  end
end
