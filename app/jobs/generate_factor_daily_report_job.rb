# frozen_string_literal: true

class GenerateFactorDailyReportJob < ApplicationJob
  queue_as :reports

  def perform(date: Date.current)
    Rails.logger.info("GenerateFactorDailyReportJob started for #{date}")

    service = FactorDailyReportGeneratorService.new(date: date)
    report = service.generate

    if report&.persisted?
      Rails.logger.info("Factor daily report generated successfully for #{date}")
      report
    else
      Rails.logger.error("Failed to generate factor daily report for #{date}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("GenerateFactorDailyReportJob failed: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    raise
  end
end
