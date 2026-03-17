# frozen_string_literal: true

module Admin
  class DashboardController < ApplicationController
    def index
      @factor_count = FactorDefinition.active.count
      @signal_count = TradingSignal.count
      @job_stats = {
        total: JobExecution.count,
        success: JobExecution.where(status: "success").count,
        failed: JobExecution.where(status: "failed").count,
        running: JobExecution.where(status: "running").count
      }

      @recent_jobs = JobExecution.recent_first.limit(10)
      @recent_signals = TradingSignal.includes(:asset).recent.limit(5)
    end
  end
end
