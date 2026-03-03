# frozen_string_literal: true

# Service for building Swarm SDK swarms with MCP integration
# This provides a Ruby-based approach to configure multi-agent systems
class SwarmBuilder
  class << self
    # Build the Asset Data Collection Swarm
    # @return [SwarmSDK::Swarm] Configured swarm instance
    def build_asset_collection_swarm
      SwarmSDK.build do
        name "Asset Data Collection Swarm"
        lead :coordinator

        agent :coordinator do
          model "claude-sonnet-4-6"
          description "Coordinates asset data collection tasks and delegates to specialized agents"

          tools []
          delegates_to [:crypto_collector, :stock_collector, :commodity_collector]

          system_prompt <<~PROMPT
            You are Asset Data Collection Coordinator. Your role is to:
              1. Receive collection requests for assets
              2. Delegate to appropriate collectors based on asset type
              3. Aggregate results and provide summary reports
              4. Handle errors and retry logic

            Asset types and their collectors:
            - crypto → Use crypto_collector (Yahoo Finance with -USD suffix)
            - stock → Use stock_collector (Yahoo Finance standard)
            - commodity → Use commodity_collector (Yahoo Finance standard)

            Always verify data quality before returning results.
            Use the web_search_prime MCP to verify current market conditions if needed.
          PROMPT
        end

        agent :crypto_collector do
          model "claude-sonnet-4-6"
          description "Specialized collector for cryptocurrency assets (BTC, ETH, etc.)"

          mcp_server :web_search_prime,
            type: :http,
            url: "https://open.bigmodel.cn/api/mcp/web_search_prime/mcp",
            headers: {
              authorization: "Bearer 8a3154af2e474012a0e8dc3231b3b71f.1voHW5XTe59RKh4S"
            }

          shared_across_delegations false

          system_prompt <<~PROMPT
            You are Crypto Data Collector. Your role is to:
              1. Fetch current price data for cryptocurrencies using available MCP tools
              2. Handle crypto-specific symbols (add -USD suffix for Yahoo API)
              3. Collect price, change_percent, volume, and timestamp data
              4. Validate data quality before returning

            For crypto assets, use -USD suffix:
            - BTC → BTC-USD
            - ETH → ETH-USD
            - SOL → SOL-USD
            etc.

            Use web_search_prime to search for current crypto prices if direct API is unavailable.

            Return structured data with: price, change_percent, volume, timestamp
          PROMPT
        end

        agent :stock_collector do
          model "claude-sonnet-4-6"
          description "Specialized collector for stock market assets (AAPL, NVDA, etc.)"

          mcp_server :web_search_prime,
            type: :http,
            url: "https://open.bigmodel.cn/api/mcp/web_search_prime/mcp",
            headers: {
              authorization: "Bearer 8a3154af2e474012a0e8dc3231b3b71f.1voHW5XTe59RKh4S"
            }

          shared_across_delegations false

          system_prompt <<~PROMPT
            You are Stock Data Collector. Your role is to:
              1. Fetch current price data for stocks using available MCP tools
              2. Use standard ticker symbols directly
              3. Collect price, change_percent, volume, and timestamp data
              4. Validate data quality before returning

            Use web_search_prime to search for current stock prices if direct API is unavailable.

            Return structured data with: price, change_percent, volume, timestamp
          PROMPT
        end

        agent :commodity_collector do
          model "claude-sonnet-4-6"
          description "Specialized collector for commodity assets (GLD, etc.)"

          mcp_server :web_search_prime,
            type: :http,
            url: "https://open.bigmodel.cn/api/mcp/web_search_prime/mcp",
            headers: {
              authorization: "Bearer 8a3154af2e474012a0e8dc3231b3b71f.1voHW5XTe59RKh4S"
            }

          shared_across_delegations false

          system_prompt <<~PROMPT
            You are Commodity Data Collector. Your role is to:
              1. Fetch current price data for commodities using available MCP tools
              2. Use standard ticker symbols directly
              3. Collect price, change_percent, volume, and timestamp data
              4. Validate data quality before returning

            Use web_search_prime to search for current commodity prices if direct API is unavailable.

            Return structured data with: price, change_percent, volume, timestamp
          PROMPT
        end

        agent :data_analyzer do
          model "claude-sonnet-4-6"
          description "Analyzes collected asset data and provides insights"

          mcp_server :web_search_prime,
            type: :http,
            url: "https://open.bigmodel.cn/api/mcp/web_search_prime/mcp",
            headers: {
              authorization: "Bearer 8a3154af2e474012a0e8dc3231b3b71f.1voHW5XTe59RKh4S"
            }

          shared_across_delegations false

          system_prompt <<~PROMPT
            You are Asset Data Analyzer. Your role is to:
              1. Analyze collected asset data for quality and anomalies
              2. Calculate basic metrics (if requested)
              3. Identify patterns or trends
              4. Provide structured analysis reports

            Look for:
            - Price anomalies or spikes
            - Volume irregularities
            - Data quality issues
            - Basic trend indicators

            Return analysis in structured format with: status, insights, anomalies, recommendations
          PROMPT
        end
      end
    end

    # Collect data for a single asset using Swarm
    # @param symbol [String] Asset symbol
    # @param asset_type [String] Asset type (crypto, stock, commodity)
    # @return [Hash] Collection results
    def collect_asset_data(symbol, asset_type)
      swarm = build_asset_collection_swarm

      prompt = case asset_type
               when "crypto"
                 "Fetch current price data for #{symbol} cryptocurrency. Search for live price, return price, change_percent, volume, and timestamp."
               when "stock"
                 "Fetch current price data for #{symbol} stock. Search for live price, return price, change_percent, volume, and timestamp."
               when "commodity"
                 "Fetch current price data for #{symbol} commodity. Search for live price, return price, change_percent, volume, and timestamp."
               else
                 "Fetch current price data for #{symbol}. Search for live price, return price, change_percent, volume, and timestamp."
               end

      result = swarm.execute(prompt)

      {
        success: true,
        symbol:,
        asset_type:,
        data: parse_swarm_result(result),
        raw_result: result,
        timestamp: Time.current
      }
    rescue StandardError => e
      Rails.logger.error "[SwarmBuilder] Failed to collect data for #{symbol}: #{e.message}"
      {
        success: false,
        symbol:,
        asset_type:,
        error: e.message,
        timestamp: Time.current
      }
    end

    private

    # Parse Swarm result and extract structured data
    # @param result [Hash] Raw swarm result
    # @return [Hash, nil] Parsed data
    def parse_swarm_result(result)
      return nil unless result

      # Try to extract data from various possible response formats
      # This is a simplified parser - enhance based on actual swarm output

      # Look for numeric patterns in the result
      result_text = result.to_s

      price_match = result_text.match(/[\$¥€£]?(\d{1,3}[,\.]?\d{3}[\.,]?\d*)/)&.[](1)
      change_match = result_text.match(/(-?\d+\.?\d*%?)\s*(?:change|variation)/i)&.[](0)
      volume_match = result_text.match(/(\d{1,3}(?:,\d{3})*(?:\.\d+)?)(?:\s*(?:volume|vol))/i)&.[](0)

      {
        price: price_match&.gsub(/[,\s]/, '')&.to_f,
        change_percent: change_match&.gsub(/[^0-9.\-]/, '')&.to_f,
        volume: volume_match&.gsub(/[,\s]/, '')&.to_i,
        timestamp: Time.current
      }
    end
  end
end
