# frozen_string_literal: true

# Service for running SwarmSDK-based asset data collection
# This integrates SwarmSDK multi-agent system with Rails application
class SwarmDataCollectorService
  class << self
    # Load and execute the asset data collection swarm
    # @param prompt [String] The task prompt to send to the swarm
    # @return [Hash] Execution results
    def collect_data(prompt = "Collect current price data for all assets")
      swarm = load_swarm

      Rails.logger.info "[SwarmDataCollector] Starting data collection swarm"

      result = swarm.execute(prompt)

      Rails.logger.info "[SwarmDataCollector] Swarm execution completed"

      {
        success: true,
        result:,
        timestamp: Time.current
      }
    rescue StandardError => e
      Rails.logger.error "[SwarmDataCollector] Swarm execution failed: #{e.message}"
      {
        success: false,
        error: e.message,
        timestamp: Time.current
      }
    end

    # Collect data for a specific asset using Swarm
    # @param symbol [String] Asset symbol
    # @param asset_type [String] Asset type (crypto, stock, commodity)
    # @return [Hash] Collection results
    def collect_for_asset(symbol, asset_type)
      prompt = build_asset_prompt(symbol, asset_type)
      collect_data(prompt)
    end

    # Analyze collected asset data using Swarm
    # @param symbol [String] Asset symbol
    # @param historical_data [Array] Array of historical data points
    # @return [Hash] Analysis results
    def analyze_asset_data(symbol, historical_data = [])
      prompt = build_analysis_prompt(symbol, historical_data)
      collect_data(prompt)
    end

    private

    # Load the asset data collection swarm from config
    def load_swarm
      config_path = Rails.root.join("config", "swarms", "asset_data_collection.yml")
      SwarmSDK.load_file(config_path)
    rescue Errno::ENOENT
      Rails.logger.error "[SwarmDataCollector] Config file not found: #{config_path}"
      raise "Swarm configuration file not found"
    end

    # Build prompt for single asset collection
    def build_asset_prompt(symbol, asset_type)
      <<~PROMPT
        Collect current price data for #{symbol} (#{asset_type} type).

        Please provide:
        - Current price
        - Change percentage
        - Volume
        - Timestamp

        Return the data in a structured JSON format.
      PROMPT
    end

    # Build prompt for asset data analysis
    def build_analysis_prompt(symbol, historical_data)
      data_summary = if historical_data.any?
        "Recent data points:\n#{historical_data.first(10).map { |d| "- #{d[:captured_at]}: $#{d[:price]}" }.join("\n")}"
      else
        "No historical data available. Use only current price."
      end

      <<~PROMPT
        Analyze the asset data for #{symbol}.

        #{data_summary}

        Provide analysis on:
        1. Overall price trend (up/down/stable)
        2. Any notable anomalies or unusual patterns
        3. Data quality assessment
        4. Recommendations for further analysis

        Return analysis in structured JSON format.
      PROMPT
    end
  end
end
