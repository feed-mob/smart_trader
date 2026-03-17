# frozen_string_literal: true

class AllocationTasksController < ApplicationController
  before_action :require_user
  before_action :set_allocation_task, only: :show

  def index
    @allocation_tasks = AllocationTask
      .includes(:trader, :allocation_decision)
      .recent
      .limit(100)
  end

  def show; end

  private

  def set_allocation_task
    @allocation_task = AllocationTask.includes(:trader, :allocation_decision).find(params[:id])
  end
end
