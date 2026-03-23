# frozen_string_literal: true

# Sidekiq Configuration for SmartTrader

Sidekiq.configure_server do |config|
  # Redis configuration
  redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
  config.redis = { url: redis_url }

  config.on(:startup) do
    sidekiq_config_path = Rails.root.join("config/sidekiq.yml")
    rendered_config = ERB.new(File.read(sidekiq_config_path)).result
    sidekiq_config = YAML.safe_load(rendered_config, permitted_classes: [Symbol], aliases: true) || {}
    schedule = sidekiq_config[:schedule] || sidekiq_config["schedule"] || {}

    if schedule.present?
      Sidekiq.schedule = schedule
      Sidekiq::Scheduler.reload_schedule!
      Rails.logger.info "[Sidekiq] Loaded #{schedule.size} recurring jobs from #{sidekiq_config_path}"
    else
      Rails.logger.warn "[Sidekiq] No recurring jobs found in #{sidekiq_config_path}"
    end
  end

  Rails.logger.info "[Sidekiq] Server configured with Redis at #{redis_url}"
end

Sidekiq.configure_client do |config|
  redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
  config.redis = { url: redis_url }

  Rails.logger.info "[Sidekiq] Client configured with Redis at #{redis_url}"
end
