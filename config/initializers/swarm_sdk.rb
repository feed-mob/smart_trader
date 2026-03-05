# frozen_string_literal: true

# SwarmSDK Configuration for SmartTrader
# Configure logging and other SwarmSDK settings

Rails.application.config.to_prepare do
  # Configure MCP logging level
  # Adjust based on your needs (:DEBUG, :INFO, :WARN, :ERROR)
  SwarmSDK::Swarm.configure_mcp_logging(Logger::WARN)

  Rails.logger.info "[SwarmSDK] Initialized successfully"
end
