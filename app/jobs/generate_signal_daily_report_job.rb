# frozen_string_literal: true

class GenerateSignalDailyReportJob < ApplicationJob
  queue_as :reports

  def perform(date: Date.current)
    Rails.logger.info("GenerateSignalDailyReportJob started for #{date}")

    service = SignalDailyReportGeneratorService.new(date: date)
    report = service.generate

    if report&.persisted?
      Rails.logger.info("Signal daily report generated successfully for #{date}")
      report
    else
      Rails.logger.error("Failed to generate signal daily report for #{date}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("GenerateSignalDailyReportJob failed: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    raise
  end
end
