# frozen_string_literal: true

# Service for collecting real asset data using Swarm SDK with MCP
class SwarmAssetDataCollector
  class << self
    # Collect data for all assets using Swarm + MCP
    # @return [Hash] Collection results summary
    def collect_all
      results = { success: 0, failed: 0, errors: [] }

      Asset.find_each do |asset|
        begin
          collect_for_asset(asset)
          results[:success] += 1
          Rails.logger.info "[SwarmAssetDataCollector] Successfully collected data for #{asset.symbol}"
        rescue StandardError => e
          results[:failed] += 1
          results[:errors] << { symbol: asset.symbol, error: e.message }
          Rails.logger.error "[SwarmAssetDataCollector] Failed to collect data for #{asset.symbol}: #{e.message}"
        end
      end

      Rails.logger.info "[SwarmAssetDataCollector] Collection complete: #{results[:success]} success, #{results[:failed]} failed"
      results
    end

    # Collect data for a single asset using Swarm
    # @param asset [Asset] The asset to collect data for
    # @return [AssetSnapshot, nil] The created snapshot or nil on failure
    def collect_for_asset(asset)
      # Build swarm with MCP
      swarm = build_swarm

      # Construct prompt based on asset type
      prompt = build_collection_prompt(asset.symbol, asset.asset_type)

      # Execute swarm
      result = swarm.execute(prompt)

      # Parse result
      parsed_data = parse_swarm_result(result)

      return nil unless parsed_data

      # Update asset with current price
      asset.update!(
        current_price: parsed_data[:price],
        last_updated: Time.current
      )

      # Create snapshot
      snapshot = asset.snapshots.create!(
        price: parsed_data[:price],
        change_percent: parsed_data[:change_percent],
        volume: parsed_data[:volume],
        captured_at: Time.current
      )

      Rails.logger.info "[SwarmAssetDataCollector] Collected #{asset.symbol}: $#{parsed_data[:price]}"
      snapshot
    end

    private

    # Build swarm with MCP configuration
    def build_swarm
      SwarmSDK.build do
        name "Asset Data Collector"
        lead :collector

        agent :collector do
          model "claude-sonnet-4-6"
          description "Collects financial asset data using web search MCP"

          mcp_server :web_search_prime,
            type: :http,
            url: "https://open.bigmodel.cn/api/mcp/web_search_prime/mcp",
            headers: {
              authorization: "Bearer 8a3154af2e474012a0e8dc3231b3b71f.1voHW5XTe59RKh4S"
            }

          shared_across_delegations false

          system_prompt <<~PROMPT
            You are a financial data collector. Your task is to search for and extract current asset price data.

            IMPORTANT: Always return the data in this exact JSON format on a single line:
            {"price": XXX.XX, "change": X.XX, "volume": XXXXX}

            - price: The current price as a number (no currency symbol)
            - change: The daily change percentage as a number (can be negative)
            - volume: The trading volume as a number (or 0 if unknown)

            Example for BTC: {"price": 43500.50, "change": 2.5, "volume": 2500000000}
            Example for AAPL: {"price": 182.50, "change": -0.5, "volume": 52000000}

            Be accurate and search for the most recent data available.
          PROMPT
        end
      end
    end

    # Build collection prompt for an asset
    # @param symbol [String] Asset symbol
    # @param asset_type [String] Asset type
    # @return [String] Prompt string
    def build_collection_prompt(symbol, asset_type)
      type_name = case asset_type
                 when "crypto" then "cryptocurrency"
                 when "stock" then "stock"
                 when "commodity" then "commodity"
                 else "asset"
                 end

      "Search for the current price of #{symbol} #{type_name}. Find the most recent trading price, daily change percentage, and trading volume. Return in the format: PRICE: $XXX.XX, CHANGE: X.XX%, VOLUME: XXXXX"
    end

    # Parse Swarm result and extract structured data
    # @param result [SwarmSDK::Result] Raw swarm result
    # @return [Hash, nil] Parsed data
    def parse_swarm_result(result)
      return nil unless result&.content

      content = result.content

      # First try to parse JSON format
      json_match = content.match(/\{[^}]*"price"[^}]*\}/i)

      if json_match
        begin
          data = JSON.parse(json_match[0])
          Rails.logger.debug "[SwarmAssetDataCollector] Parsed JSON: #{data.inspect}"
          return {
            price: data["price"]&.to_f,
            change_percent: data["change"]&.to_f,
            volume: data["volume"]&.to_i,
            timestamp: Time.current
          }
        rescue JSON::ParserError => e
          Rails.logger.warn "[SwarmAssetDataCollector] JSON parse failed: #{e.message}, falling back to regex extraction"
        end
      end

      # Fallback to regex extraction
      # Extract price
      price = extract_price(content)
      return nil unless price

      # Extract change percent
      change = extract_change(content)

      # Extract volume
      volume = extract_volume(content)

      {
        price:,
        change_percent: change,
        volume: volume,
        timestamp: Time.current
      }
    end

    # Extract price from content
    # @param content [String] Result content
    # @return [Float, nil] Extracted price
    def extract_price(content)
      # Try multiple patterns
      patterns = [
        /PRICE:\s*\$?(\d{1,3}[,\.]?\d{3}[\.,]?\d*)/i,
        /Current Price:\s*\$?(\d{1,3}[,\.]?\d{3}[\.,]?\d*)/i,
        /price[:\s]*\$?(\d{1,3}[,\.]?\d{3}[\.,]?\d*)/i,
        /[\$¥€£](\d{1,3}[,\.]?\d{3}[\.,]?\d*)/i,
        /(\d{1,3}[,\.]?\d{3}[\.,]?\d*)\s*USD/i
      ]

      patterns.each do |pattern|
        match = content.match(pattern)
        return match[1].gsub(/[,\.]/, '').to_f if match
      end

      nil
    end

    # Extract change percent from content
    # @param content [String] Result content
    # @return [Float, nil] Extracted change percent
    def extract_change(content)
      patterns = [
        /CHANGE:\s*(-?\d+\.?\d*)%/i,
        /change\s*[:]\s*(-?\d+\.?\d*)%/i,
        /Change Percentage:\s*(-?\d+\.?\d*)%/i,
        /(-?\d+\.?\d*)%\s*(?:change|variation)/i
      ]

      patterns.each do |pattern|
        match = content.match(pattern)
        return match[1].to_f if match
      end

      nil
    end

    # Extract volume from content
    # @param content [String] Result content
    # @return [Integer, nil] Extracted volume
    def extract_volume(content)
      patterns = [
        /VOLUME:\s*(\d{1,3}(?:,\d{3})*(?:\.\d+)?)/i,
        /volume\s*[:]\s*(\d{1,3}(?:,\d{3})*(?:\.\d+)?)/i,
        /Trading Volume:\s*(\d{1,3}(?:,\d{3})*(?:\.\d+)?)/i,
        /(\d{1,3}(?:,\d{3})*(?:\.\d+)?)(?:\s*(?:volume|vol|shares))/i
      ]

      patterns.each do |pattern|
        match = content.match(pattern)
        return match[1].gsub(/[,\.]/, '').to_i if match
      end

      nil
    end
  end
end
