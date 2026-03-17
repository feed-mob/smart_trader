# frozen_string_literal: true

class DailyAllocationDecisionGenerationService
  def initialize(run_on: Date.current, force: false, scope: Trader.active)
    @run_on = run_on
    @force = force
    @scope = scope
  end

  def call
    results = { success: 0, failed: 0, skipped: 0 }

    @scope.find_each do |trader|
      outcome = generate_for_trader(trader)
      results[outcome] += 1
    end

    results
  end

  private

  def generate_for_trader(trader)
    if !@force && trader.allocation_decisions.where(decision_date: @run_on, source: "llm").exists?
      Rails.logger.info("[DailyAllocationDecisionGenerationService] skipped trader=#{trader.id} run_on=#{@run_on}")
      return :skipped
    end

    decision = AiAllocationService.new(trader).generate_and_persist_recommendation!
    decision&.generated? ? :success : :failed
  rescue StandardError => e
    Rails.logger.error("[DailyAllocationDecisionGenerationService] failed trader=#{trader.id}: #{e.message}")
    :failed
  end
end
