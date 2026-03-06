# frozen_string_literal: true

# Yahoo Finance Service for fetching market data
# Provides real-time price, change percent, volume, and timestamp data
class YahooFinanceService
  include HTTParty
  base_uri "https://query1.finance.yahoo.com"

  class << self
    # Fetch current price data for a given symbol
    # @param symbol [String] The asset symbol (e.g., "AAPL", "BTC-USD")
    # @return [Hash, nil] Price data with keys: price, change_percent, volume, timestamp
    def get_price_data(symbol)
      # Handle crypto symbols (need -USD suffix for Yahoo Finance)
      api_symbol = normalize_symbol_for_yahoo(symbol)

      response = get("/v8/finance/chart/#{api_symbol}", {
        timeout: 10,
        headers: { "User-Agent" => "Mozilla/5.0" }
      })

      return nil unless response.success?

      data = JSON.parse(response.body)
      result = data.dig("chart", "result", 0)
      return nil unless result

      meta = result["meta"]
      timestamp = meta.dig("regularMarketTime")

      {
        price: meta.dig("regularMarketPrice")&.to_f,
        change_percent: meta.dig("regularMarketChangePercent")&.to_f,
        volume: meta.dig("regularMarketVolume")&.to_i,
        timestamp: timestamp ? Time.at(timestamp) : Time.current
      }
    rescue StandardError => e
      Rails.logger.error "[YahooFinanceService] API error for #{symbol}: #{e.message}"
      nil
    end

    # Fetch multiple price data points for historical analysis
    # @param symbol [String] The asset symbol
    # @param interval [String] Time interval (1m, 5m, 15m, 1h, 1d, etc.)
    # @param range [String] Date range (1d, 5d, 1mo, 3mo, 6mo, 1y, max)
    # @return [Array<Hash>] Array of price data points
    def get_historical_data(symbol, interval: "1h", range: "5d")
      api_symbol = normalize_symbol_for_yahoo(symbol)

      response = get("/v8/finance/chart/#{api_symbol}", {
        query: { interval:, range: },
        timeout: 15,
        headers: { "User-Agent" => "Mozilla/5.0" }
      })

      return [] unless response.success?

      data = JSON.parse(response.body)
      result = data.dig("chart", "result", 0)
      return [] unless result

      timestamps = result["timestamp"] || []
      indicators = result["indicators"]
      quote = indicators["quote"]&.first || {}

      timestamps.each_with_index.map do |ts, i|
        {
          timestamp: Time.at(ts),
          price: quote["close"]&.[](i)&.to_f,
          open: quote["open"]&.[](i)&.to_f,
          high: quote["high"]&.[](i)&.to_f,
          low: quote["low"]&.[](i)&.to_f,
          volume: quote["volume"]&.[](i)&.to_i
        }
      end.compact
    rescue StandardError => e
      Rails.logger.error "[YahooFinanceService] Historical data error for #{symbol}: #{e.message}"
      []
    end

    # Batch fetch stock data using Yahoo Screener API
    # @param scr_id [String] Screener ID (e.g., "largest_market_cap", "most_actives")
    # @param count [Integer] Number of stocks to fetch (max 100)
    # @param start [Integer] Offset for pagination
    # @return [Array<Hash>] Array of stock data with keys: symbol, name, exchange, price, change_percent, volume, market_cap, timestamp
    def get_screener_data(scr_id: "largest_market_cap", count: 100, start: 0)
      url = "https://query1.finance.yahoo.com/v1/finance/screener/predefined/saved?scrIds=#{scr_id}&count=#{count}&start=#{start}"

      # Use curl to fetch data (more reliable in WSL environments)
      response = `curl -s "#{url}" -H "User-Agent: Mozilla/5.0"`

      return [] if response.empty?

      data = JSON.parse(response)
      quotes = data.dig("finance", "result", 0, "quotes")
      return [] unless quotes

      quotes.map do |quote|
        timestamp = quote.dig("regularMarketTime")

        {
          symbol: quote["symbol"],
          name: quote["shortName"] || quote["longName"] || quote["symbol"],
          exchange: quote["exchange"] || "UNKNOWN",
          price: quote.dig("regularMarketPrice")&.to_f,
          change_percent: quote.dig("regularMarketChangePercent")&.to_f,
          volume: quote.dig("regularMarketVolume")&.to_i,
          market_cap: quote.dig("marketCap")&.to_i,
          timestamp: timestamp ? Time.at(timestamp) : Time.current
        }
      end
    rescue StandardError => e
      Rails.logger.error "[YahooFinanceService] Screener API error: #{e.message}"
      []
    end

    # Check if a symbol exists/is valid on Yahoo Finance
    # @param symbol [String] The asset symbol to check
    # @return [Boolean] True if symbol is valid
    def valid_symbol?(symbol)
      api_symbol = normalize_symbol_for_yahoo(symbol)
      response = get("/v8/finance/chart/#{api_symbol}", {
        timeout: 5,
        headers: { "User-Agent" => "Mozilla/5.0" }
      })
      response.success? && JSON.parse(response.body).dig("chart", "result").present?
    rescue StandardError
      false
    end

    private

    # Normalize symbol for Yahoo Finance API
    # Crypto symbols need -USD suffix (e.g., BTC -> BTC-USD)
    # Stock symbols remain as-is
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
