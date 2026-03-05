# frozen_string_literal: true

# SwarmSDK Configuration for SmartTrader
# Configure logging and other SwarmSDK settings

Rails.application.config.to_prepare do
  # Configure SwarmSDK settings
  SwarmSDK.configure do |config|
    # API Keys (using Anthropic via OpenAI-compatible endpoint)
    config.openai_api_key = ENV.fetch("ANTHROPIC_API_KEY")
    config.openai_api_base = ENV.fetch("ANTHROPIC_API_BASE")

    # Agent Defaults
    config.default_model = "claude-sonnet-4-6"
    config.default_provider = "openai"
    config.agent_request_timeout = 600

    # Concurrency
    config.global_concurrency_limit = 100
    config.local_concurrency_limit = 20

    # Timeouts
    config.bash_command_timeout = 180_000
    config.web_fetch_timeout = 120

    # Limits
    config.output_character_limit = 50_000
    config.read_line_limit = 5000

    # WebFetch LLM
    config.webfetch_provider = "openai"
    config.webfetch_model = "claude-sonnet-4-6"
    config.webfetch_max_tokens = 8192

    # Security
    config.allow_filesystem_tools = true
  end

  # Configure MCP logging level
  # Adjust based on your needs (Logger::DEBUG, ::INFO, ::WARN, ::ERROR)
  SwarmSDK::Swarm.configure_mcp_logging(Logger::WARN)

  # Verify configuration
  Rails.logger.info "[SwarmSDK] Initialized with default_model: #{SwarmSDK.config.default_model}"
end
