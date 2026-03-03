# frozen_string_literal: true

# Multi-source data fetcher with fallback options
# Tries multiple APIs to get real asset data
class MultiSourceDataFetcher
  class << self
    # Fetch price data for an asset, trying multiple sources
    # @param symbol [String] Asset symbol
    # @param asset_type [String] Asset type (crypto, stock, commodity)
    # @return [Hash, nil] Price data
    def fetch_price_data(symbol, asset_type)
      Rails.logger.info "[MultiSourceDataFetcher] Fetching data for #{symbol} (#{asset_type})"

      # Try sources in order of preference
      case asset_type
      when "crypto"
        fetch_crypto_data(symbol)
      when "stock"
        fetch_stock_data(symbol)
      when "commodity"
        fetch_stock_data(symbol)  # Commodities use stock-like APIs
      else
        fetch_generic_data(symbol)
      end
    end

    private

    # Fetch crypto data using Coingecko
    # @param symbol [String] Crypto symbol
    # @return [Hash, nil] Price data
    def fetch_crypto_data(symbol)
      coingecko_id = symbol_to_coingecko_id(symbol)
      return nil unless coingecko_id

      uri = URI("https://api.coingecko.com/api/v3/simple/price?ids=#{coingecko_id}&vs_currencies=usd&include_24hr_change=true")

      begin
        response = Net::HTTP.get_response(uri, read_timeout: 10)
        return nil unless response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(response.body)

        return nil unless data[coingecko_id]

        usd_data = data[coingecko_id]["usd"]
        return nil unless usd_data

        {
          price: usd_data["price"]&.to_f,
          change_percent: usd_data["24h_change"]&.to_f,
          volume: nil,  # Coingecko doesn't provide volume in this endpoint
          timestamp: Time.current
        }
      rescue StandardError => e
        Rails.logger.error "[MultiSourceDataFetcher] Coingecko error: #{e.message}"
        nil
      end
    end

    # Fetch stock data using Yahoo Finance
    # @param symbol [String] Stock symbol
    # @return [Hash, nil] Price data
    def fetch_stock_data(symbol)
      # Normalize symbol for Yahoo
      api_symbol = normalize_symbol_for_yahoo(symbol)

      uri = URI("https://query1.finance.yahoo.com/v8/finance/chart/#{api_symbol}")

      begin
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 10
        http.read_timeout = 10

        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "Mozilla/5.0"

        response = http.request(request)
        return nil unless response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(response.body)
        result = data.dig("chart", "result", 0)
        return nil unless result

        meta = result["meta"]
        return nil unless meta

        {
          price: meta.dig("regularMarketPrice")&.to_f,
          change_percent: meta.dig("regularMarketChangePercent")&.to_f,
          volume: meta.dig("regularMarketVolume")&.to_i,
          timestamp: meta.dig("regularMarketTime") ? Time.at(meta["regularMarketTime"]) : Time.current
        }
      rescue StandardError => e
        Rails.logger.error "[MultiSourceDataFetcher] Yahoo Finance error: #{e.message}"
        nil
      end
    end

    # Fetch generic data (last resort)
    # @param symbol [String] Symbol
    # @return [Hash, nil] Mock data with note
    def fetch_generic_data(symbol)
      Rails.logger.warn "[MultiSourceDataFetcher] All sources failed for #{symbol}, returning nil"
      nil
    end

    # Convert symbol to Coingecko ID
    # @param symbol [String] Asset symbol
    # @return [String, nil] Coingecko ID
    def symbol_to_coingecko_id(symbol)
      mapping = {
        "BTC" => "bitcoin",
        "ETH" => "ethereum",
        "SOL" => "solana",
        "DOGE" => "dogecoin",
        "ADA" => "cardano",
        "XRP" => "ripple",
        "DOT" => "polkadot",
        "LINK" => "chainlink",
        "MATIC" => "matic-network"
      }
      mapping[symbol.upcase]
    end

    # Normalize symbol for Yahoo Finance API
    # @param symbol [String] Asset symbol
    # @return [String] Normalized symbol
    def normalize_symbol_for_yahoo(symbol)
      case symbol.upcase
      when "BTC", "ETH", "SOL", "DOGE", "ADA"
        "#{symbol}-USD"
      else
        symbol
      end
    end
  end
end
