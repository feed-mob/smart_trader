# frozen_string_literal: true

# Sidekiq Scheduler configuration
# This file defines cron jobs for scheduled tasks

:queues:
  - default
  - reports

:schedule:
  # 每日因子日报 - 每天 20:00 生成
  generate_factor_daily_report:
    cron: "0 20 * * *"
    class: "GenerateFactorDailyReportJob"
    queue: "reports"

  # 每日信号日报 - 每天 20:30 生成
  generate_signal_daily_report:
    cron: "30 20 * * *"
    class: "GenerateSignalDailyReportJob"
    queue: "reports"
