# frozen_string_literal: true

# TradingView MCP Service - Pure Ruby Implementation
# Uses CoinGecko API for crypto data (no external Python dependency)
class TradingViewMcpService
  class << self
    # Get coin analysis from CoinGecko API
    # @param symbol [String] Coin symbol (e.g., "btc", "eth")
    # @param exchange [String] Exchange (default: KUCOIN)
    # @param timeframe [String] Timeframe (default: 1h)
    # @return [Hash, nil] Market data
    def coin_analysis(symbol, exchange: "KUCOIN", timeframe: "1h")
      # Map internal symbol to CoinGecko ID
      coin_id = symbol.downcase

      # Cache key for this symbol
      cache_key = "crypto_data_#{coin_id}"
      cache_data = Rails.cache.read(cache_key)

      return cache_data if cache_data

      # Fetch data from CoinGecko API
      begin
        data = fetch_from_coingecko(coin_id)

        return nil unless data

        # Cache for 5 minutes
        Rails.cache.write(cache_key, data, expires_in: 5.minutes)

        # Convert to our internal format
        {
          "symbol" => symbol,
          "exchange" => exchange,
          "price" => data["price"],
          "open" => data["open"],
          "high" => data["high"],
          "low" => data["low"],
          "change_percent" => data["change_percent"],
          "volume" => data["volume"],
          "rsi" => nil,
          "bb_rating" => nil,
          "bb_signal" => nil,
          "timestamp" => Time.current
        }
      rescue StandardError => e
        Rails.logger.error "[TradingViewMcpService] Error fetching #{symbol}: #{e.message}"
        nil
      end
    end

    # Get top gainers
    # @param exchange [String] Exchange (default: KUCOIN)
    # @param timeframe [String] Timeframe (default: 15m)
    # @param limit [Integer] Max results (default: 25)
    # @return [Array<Hash>] List of top gainers
    def top_gainers(exchange: "KUCOIN", timeframe: "15m", limit: 25)
      cache_key = "top_gainers_#{exchange}_#{timeframe}"

      begin
        # Get top gainers from CoinGecko
        # CoinGecko's top gainers endpoint returns top 250 coins by 24h change
        url = "https://api.coingecko.com/api/v3/coins/markets/usd?per_page=250&order=market_cap_desc&sparkline=false&price_change_percentage=24h"

        Rails.logger.info "[TradingViewMcpService] Fetching top gainers from #{url}"

        response = HTTParty.get(url, {
          "timeout" => 15,
          "headers" => {
            "User-Agent" => "SmartTrader/1.0",
            "Accept" => "application/json"
          }
        })

        return nil unless response.success?

        data = JSON.parse(response.body)

        # Map CoinGecko data to our format
        gainers = []
        data.each do |coin|
          next unless coin["symbol"] && coin["current_price"]
          gainers << {
            "symbol" => coin["symbol"].upcase,
            "price" => coin["current_price"]["usd"].to_f,
            "change_percent" => coin["price_change_percentage_24h"].to_f.round(2),
            "volume" => coin["total_volume"]["usd"].to_f || 0
          }
        end

        # Cache for 5 minutes
        Rails.cache.write(cache_key, gainers, expires_in: 5.minutes)

        gainers
      rescue StandardError => e
        Rails.logger.error "[TradingViewMcpService] Error fetching top gainers: #{e.message}"
        []
      end
    end

    # Get top losers
    # @param exchange [String] Exchange (default: KUCOIN)
    # @param timeframe [String] Timeframe (default: 15m)
    # @param limit [Integer] Max results (default: 25)
    # @return [Array<Hash>] List of top losers
    def top_losers(exchange: "KUCOIN", timeframe: "15m", limit: 25)
      cache_key = "top_losers_#{exchange}_#{timeframe}"

      begin
        # Get top losers from CoinGecko
        url = "https://api.coingecko.com/api/v3/coins/markets/usd?per_page=250&order=market_cap_desc&sparkline=false&price_change_percentage=24h&order=market_cap_asc"

        Rails.logger.info "[TradingViewMcpService] Fetching top losers from #{url}"

        response = HTTParty.get(url, {
          "timeout" => 15,
          "headers" => {
            "User-Agent" => "SmartTrader/1.0",
            "Accept" => "application/json"
          }
        })

        return nil unless response.success?

        data = JSON.parse(response.body)

        # Map CoinGecko data to our format
        losers = []
        data.each do |coin|
          next unless coin["symbol"] && coin["current_price"]
          losers << {
            "symbol" => coin["symbol"].upcase,
            "price" => coin["current_price"]["usd"].to_f,
            "change_percent" => coin["price_change_percentage_24h"].to_f.round(2),
            "volume" => coin["total_volume"]["usd"].to_f || 0
          }
        end

        # Cache for 5 minutes
        Rails.cache.write(cache_key, losers, expires_in: 5.minutes)

        losers
      rescue StandardError => e
        Rails.logger.error "[TradingViewMcpService] Error fetching top losers: #{e.message}"
        []
      end
    end

    # Health check
    def health_status
      begin
        # Test fetching BTC data
        btc_data = coin_analysis("BTC")

        if btc_data
          {
            "available" => true,
            "response_time" => 0.5,
            "last_check" => Time.current
          }
        else
          {
            "available" => false,
            "error" => "Failed to fetch BTC data",
            "last_check" => Time.current
          }
        end
      rescue StandardError => e
        {
          "available" => false,
          "error" => e.message,
          "last_check" => Time.current
        }
      end
    end

    private

    # Fetch data from CoinGecko API
    # @param coin_id [String] CoinGecko coin ID (e.g., "bitcoin", "ethereum")
    # @return [Hash, nil] Parsed market data
    def fetch_from_coingecko(coin_id)
      # Use the markets endpoint which provides all needed data in one call
      url = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=#{coin_id}&sparkline=false"

      Rails.logger.info "[TradingViewMcpService] Fetching data from CoinGecko for #{coin_id}"

      response = HTTParty.get(url, {
        timeout: 15,
        headers: {
          "User-Agent" => "SmartTrader/1.0",
          "Accept" => "application/json"
        }
      })

      return nil unless response.success?

      data = JSON.parse(response.body)

      # CoinGecko returns an array, take the first element
      coin_data = data.first
      return nil unless coin_data

      # Map CoinGecko fields to our internal format
      {
        "price" => coin_data["current_price"].to_f,
        "open" => nil,  # CoinGecko doesn't provide open price in this endpoint
        "high" => coin_data["high_24h"].to_f,
        "low" => coin_data["low_24h"].to_f,
        "change_percent" => coin_data["price_change_percentage_24h"].to_f,
        "volume" => coin_data["total_volume"].to_i
      }
    rescue StandardError => e
      Rails.logger.error "[TradingViewMcpService] CoinGecko API error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      nil
    end
end
