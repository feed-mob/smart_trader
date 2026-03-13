# frozen_string_literal: true

class AllocationDecisionsController < ApplicationController
  before_action :require_user
  before_action :set_allocation_decision, only: %i[show execute]

  def index
    @allocation_decisions = AllocationDecision
      .includes(:trader, :trading_strategy)
      .recent
      .limit(100)
  end

  def show
    @recommendation = @allocation_decision.recommendation_payload_symbolized
  end

  def execute
    AllocationExecutionService.new(@allocation_decision).call
    redirect_to allocation_decision_path(@allocation_decision), notice: "配置建议已执行"
  rescue StandardError => e
    redirect_to allocation_decision_path(@allocation_decision), alert: "执行失败: #{e.message}"
  end

  private

  def set_allocation_decision
    @allocation_decision = AllocationDecision.includes(:trader, :trading_strategy).find(params[:id])
  end
end
