# frozen_string_literal: true

class TraderReflectionsController < ApplicationController
  before_action :require_user
  before_action :set_trader
  before_action :set_trader_reflection, only: %i[show apply_adjustment]

  def create
    reflection = TraderReflectionService.new(@trader).call
    redirect_to trader_trader_reflection_path(@trader, reflection), notice: "反思报告生成成功"
  rescue StandardError => e
    redirect_to trader_path(@trader), alert: "反思报告生成失败：#{e.message}"
  end

  def show; end

  def apply_adjustment
    ApplyTraderReflectionAdjustmentService.new(
      @trader_reflection,
      parameter: params[:parameter]
    ).call

    redirect_to trader_trader_reflection_path(@trader, @trader_reflection), notice: "策略参数已应用到当前策略"
  rescue StandardError => e
    redirect_to trader_trader_reflection_path(@trader, @trader_reflection), alert: "应用建议失败：#{e.message}"
  end

  private

  def set_trader
    @trader = Trader.find(params[:trader_id])
  end

  def set_trader_reflection
    @trader_reflection = @trader.trader_reflections.find(params[:id])
  end
end
