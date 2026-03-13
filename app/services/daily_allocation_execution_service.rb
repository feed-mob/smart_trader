# frozen_string_literal: true

class DailyAllocationExecutionService
  def initialize(run_on: Date.current, force: false, scope: Trader.active, run_at: Time.current)
    @run_on = run_on
    @force = force
    @scope = scope
    @run_at = run_at
  end

  def call
    results = { success: 0, failed: 0, skipped: 0 }

    @scope.find_each do |trader|
      outcome = execute_for_trader(trader)
      results[outcome] += 1
    end

    results
  end

  private

  def execute_for_trader(trader)
    decision = trader.allocation_decisions
      .successful
      .where(decision_date: @run_on)
      .recent
      .first

    unless decision
      Rails.logger.info("[DailyAllocationExecutionService] skipped trader=#{trader.id} run_on=#{@run_on} reason=no_decision")
      return :skipped
    end

    if !@force && decision.allocation_tasks.where(status: [:running, :completed]).exists?
      Rails.logger.info("[DailyAllocationExecutionService] skipped trader=#{trader.id} decision=#{decision.id} reason=already_executed")
      return :skipped
    end

    AllocationExecutionService.new(decision, run_at: execution_time).call
    :success
  rescue StandardError => e
    Rails.logger.error("[DailyAllocationExecutionService] failed trader=#{trader.id}: #{e.message}")
    :failed
  end

  def execution_time
    @execution_time ||= begin
      if @run_at.to_date == @run_on
        @run_at
      else
        @run_on.end_of_day
      end
    end
  end
end
