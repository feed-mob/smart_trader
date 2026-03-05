# frozen_string_literal: true

# Sidekiq Configuration for SmartTrader

Sidekiq.configure_server do |config|
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