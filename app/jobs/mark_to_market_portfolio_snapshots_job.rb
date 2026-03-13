# frozen_string_literal: true

class MarkToMarketPortfolioSnapshotsJob < ApplicationJob
  queue_as :default

  def perform(run_at: Time.current.iso8601)
    snapshot_time = run_at.is_a?(Time) ? run_at : Time.zone.parse(run_at.to_s)
    Rails.logger.info("MarkToMarketPortfolioSnapshotsJob started run_at=#{snapshot_time}")

    results = MarkToMarketPortfolioSnapshotService.new(run_at: snapshot_time).call

    Rails.logger.info("MarkToMarketPortfolioSnapshotsJob completed: #{results}")
    results
  end
end
