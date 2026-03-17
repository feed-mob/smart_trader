# frozen_string_literal: true

date_arg = ARGV[0]
force = ARGV.delete("--force").present?
run_at = date_arg.present? ? Time.zone.parse("#{date_arg} 23:59:59") : 1.day.ago.end_of_day

unless run_at
  raise ArgumentError, "无法解析日期参数，请使用 YYYY-MM-DD，例如：bin/rails runner script/backfill_mark_to_market_snapshots.rb 2026-03-16"
end

results = MarkToMarketPortfolioSnapshotService.new(run_at: run_at, force: force).call

puts "Mark-to-market snapshots backfilled for #{run_at.to_date}: #{results.inspect}"
