# frozen_string_literal: true

module Admin
  class JobExecutionsController < ApplicationController
    def index
      @executions = JobExecution.recent_first
                                .page(params[:page])
                                .per(25)

      # 筛选条件
      @executions = @executions.by_job_name(params[:job_name]) if params[:job_name].present?
      @executions = @executions.by_status(params[:status]) if params[:status].present?

      # 时间范围筛选
      if params[:start_date].present? && params[:end_date].present?
        start_date = Date.parse(params[:start_date]).beginning_of_day
        end_date = Date.parse(params[:end_date]).end_of_day
        @executions = @executions.where(started_at: start_date..end_date)
      end

      # 统计数据
      @stats = {
        total: JobExecution.count,
        success: JobExecution.where(status: "success").count,
        failed: JobExecution.where(status: "failed").count,
        running: JobExecution.where(status: "running").count
      }

      # 获取所有 job 名称用于筛选下拉框
      @job_names = JobExecution.distinct.pluck(:job_name).sort
    end

    def show
      @execution = JobExecution.find(params[:id])
    end
  end
end
