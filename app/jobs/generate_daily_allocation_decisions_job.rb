# frozen_string_literal: true

class GenerateDailyAllocationDecisionsJob < ApplicationJob
  queue_as :default

  def perform(run_on: Date.current.to_s, force: false)
    run_date = run_on.is_a?(Date) ? run_on : Date.parse(run_on.to_s)
    Rails.logger.info("GenerateDailyAllocationDecisionsJob started run_on=#{run_date} force=#{force}")

    results = DailyAllocationDecisionGenerationService.new(run_on: run_date, force: force).call

    Rails.logger.info("GenerateDailyAllocationDecisionsJob completed: #{results}")
    results
  end
end
