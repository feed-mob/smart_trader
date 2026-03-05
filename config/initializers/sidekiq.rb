# frozen_string_literal: true

# Sidekiq Configuration for SmartTrader

Sidekiq.configure_server do |config|
  config.logger = Rails.logger
  config.logger.level = Rails.logger.level

  # Redis configuration
  redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
  config.redis = { url: redis_url }

  Rails.logger.info "[Sidekiq] Server configured with Redis at #{redis_url}"
end

Sidekiq.configure_client do |config|
  redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
  config.redis = { url: redis_url }

  Rails.logger.info "[Sidekiq] Client configured with Redis at #{redis_url}"
end

# Load sidekiq-cron schedule file
schedule_file = Rails.root.join("config", "sidekiq_schedule.yml")

if File.exist?(schedule_file)
  Sidekiq::Cron::Job.load_from_hash(YAML.load_file(schedule_file))
  Rails.logger.info "[Sidekiq-Cron] Loaded schedule from #{schedule_file}"
end
