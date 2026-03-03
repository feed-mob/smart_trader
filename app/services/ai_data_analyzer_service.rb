# frozen_string_literal: true

# AI Data Analyzer Service - Uses RubyLLM for asset trend analysis
# Provides AI-powered insights on collected market data

class AIDataAnalyzerService
  # Default number of snapshots to analyze (48 hours)
  DEFAULT_SNAPSHOT_COUNT = 48

  # Cache duration for analysis results
  CACHE_TTL = 1.hour

  class << self
    # Analyze asset trend and generate AI insights
    # @param asset [Asset] The asset to analyze
    # @param hours [Integer] Number of hours of data to analyze
    # @return [Hash] Analysis results with trend, signals, recommendations
    def analyze_asset_trend(asset, hours: DEFAULT_SNAPSHOT_COUNT)
      cache_key = "ai_analysis_#{asset.id}_#{hours}h"

      # Check cache first
      cached = Rails.cache.read(cache_key)
      return cached if cached

      Rails.logger.info "[AIDataAnalyzer] Analyzing trend for #{asset.symbol} (#{hours}h)"

      # Get recent snapshots
      snapshots = asset.asset_snapshots
                         .where(captured_at: hours.hours.ago..Time.current)
                         .order(captured_at: :asc)

      if snapshots.empty?
        return build_empty_result(asset, "No data available for analysis")
      end

      # Prepare data for analysis
      data_summary = prepare_data_summary(asset, snapshots)

      # Generate AI insights using RubyLLM
      insights = generate_ai_insights(asset, data_summary)

      # Store result in cache
      Rails.cache.write(cache_key, insights, expires_in: CACHE_TTL)

      Rails.logger.info "[AIDataAnalyzer] Analysis completed for #{asset.symbol}"
      insights
    rescue StandardError => e
      Rails.logger.error "[AIDataAnalyzer] Analysis failed for #{asset.symbol}: #{e.message}"
      build_error_result(asset, e.message)
    end

    # Batch analyze multiple assets
    # @param assets [Array<Asset>] Assets to analyze
    # @return [Hash] Batch analysis results
    def analyze_multiple_assets(assets)
      results = {}

      assets.each do |asset|
        results[asset.symbol] = analyze_asset_trend(asset, hours: 24)
      end

      {
        success: true,
        data: results,
        count: results.size,
        timestamp: Time.current.iso8601
      }
    end

    # Generate trading signal based on historical data
    # @param asset [Asset] The asset to analyze
    # @return [Hash] Trading signals
    def generate_trading_signals(asset)
      snapshots = asset.asset_snapshots.recent(48)
      return build_empty_signals if snapshots.empty?

      # Calculate basic indicators
      prices = snapshots.pluck(:price)
      current_price = prices.last
      avg_price = prices.sum / prices.size
      sma_24 = snapshots.where(captured_at: 24.hours.ago..Time.current).average(:price)
      volume_avg = snapshots.average(:volume)

      # Determine trend direction
      trend = if current_price > avg_price
        "bullish"
      elsif current_price < avg_price
        "bearish"
      else
        "neutral"
      end

      # Calculate support/resistance levels
      price_range = prices.max - prices.min
      support_level = prices.min + (price_range * 0.236)
      resistance_level = prices.max - (price_range * 0.236)

      {
        trend_direction: trend,
        current_price:,
        avg_price: avg_price.to_f.round(2),
        sma_24: sma_24&.to_f&.round(2),
        support_level: support_level.to_f.round(2),
        resistance_level: resistance_level.to_f.round(2),
        volume_avg: volume_avg&.to_i,
        timestamp: Time.current.iso8601
      }
    end

    private

    # Prepare data summary for AI analysis
    def prepare_data_summary(asset, snapshots)
      prices = snapshots.pluck(:price)

      {
        symbol: asset.symbol,
        name: asset.name,
        asset_type: asset.asset_type,
        current_price: prices.last,
        price_data: snapshots.map { |s| "#{s.captured_at.strftime('%Y-%m-%d %H:%M')}: $#{s.price} (#{s.change_percent}%)" },
        statistics: {
          count: snapshots.count,
          min_price: prices.min,
          max_price: prices.max,
          avg_price: prices.sum / prices.size,
          price_change: ((prices.last - prices.first) / prices.first * 100).round(2)
        }
      }
    end

    # Generate AI insights using RubyLLM
    def generate_ai_insights(asset, data_summary)
      return build_empty_result(asset, "AI analysis not available") unless RubyLLM.configured?

      prompt = build_analysis_prompt(asset, data_summary)

      Rails.logger.info "[AIDataAnalyzer] Generating AI insights for #{asset.symbol}"

      # Use RubyLLM to generate analysis
      response = RubyLLM.chat(
        model: "claude-sonnet-4",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.3
      )

      # Parse AI response
      parse_ai_response(asset, response)
    rescue StandardError => e
      Rails.logger.error "[AIDataAnalyzer] AI generation failed: #{e.message}"
      build_fallback_result(asset, data_summary)
    end

    # Build analysis prompt for LLM
    def build_analysis_prompt(asset, data_summary)
      stats = data_summary[:statistics]

      <<~PROMPT
        Analyze the following market data for #{asset.name} (#{asset.symbol}):

        **Current Status**:
        - Current Price: $#{data_summary[:current_price]}
        - Price Change (Period): #{stats[:price_change]}%
        - Min Price: $#{stats[:min_price]}
        - Max Price: $#{stats[:max_price]}
        - Avg Price: $#{stats[:avg_price].round(2)}
        - Data Points: #{stats[:count]}

        **Price History (Last #{stats[:count]} points)**:
        #{data_summary[:price_data].take(10).join("\n")}
        ...

        Please provide:
        1. **Trend Analysis**: Overall trend direction (bullish/bearish/neutral)
        2. **Key Levels**: Support and resistance price levels
        3. **Trading Signals**: Buy/Sell/Hold recommendation with confidence level
        4. **Risk Factors**: Any notable risks or volatility indicators

        Format your response as JSON with this structure:
        {
          "trend_direction": "bullish|bearish|neutral",
          "support_level": price,
          "resistance_level": price,
          "trading_signal": "buy|sell|hold",
          "confidence": "high|medium|low",
          "risk_factors": ["factor1", "factor2"],
          "analysis": "detailed explanation"
        }
      PROMPT
    end

    # Parse AI response
    def parse_ai_response(asset, response)
      content = response.dig(:message, :content)

      # Try to extract JSON from response
      json_match = content.match(/\{[\s\S]*?\}/)

      if json_match
        begin
          insights = JSON.parse(json_match[0])
          build_success_result(asset, insights)
        rescue JSON::ParserError
          build_text_result(asset, content)
        end
      else
        build_text_result(asset, content)
      end
    end

    # Build successful result
    def build_success_result(asset, insights)
      {
        success: true,
        asset_id: asset.id,
        symbol: asset.symbol,
        trend_direction: insights["trend_direction"] || "neutral",
        support_level: insights["support_level"],
        resistance_level: insights["resistance_level"],
        trading_signal: insights["trading_signal"] || "hold",
        confidence: insights["confidence"] || "medium",
        risk_factors: insights["risk_factors"] || [],
        analysis: insights["analysis"] || "Analysis completed",
        timestamp: Time.current.iso8601
      }
    end

    # Build result with text analysis
    def build_text_result(asset, text)
      {
        success: true,
        asset_id: asset.id,
        symbol: asset.symbol,
        analysis: text,
        timestamp: Time.current.iso8601,
        is_text_response: true
      }
    end

    # Build empty result
    def build_empty_result(asset, message)
      {
        success: false,
        asset_id: asset.id,
        symbol: asset.symbol,
        error: message,
        timestamp: Time.current.iso8601
      }
    end

    # Build error result
    def build_error_result(asset, error_message)
      {
        success: false,
        asset_id: asset.id,
        symbol: asset.symbol,
        error: error_message,
        timestamp: Time.current.iso8601
      }
    end

    # Build fallback result (when AI fails)
    def build_fallback_result(asset, data_summary)
      stats = data_summary[:statistics]
      price_change = stats[:price_change]

      trend = if price_change > 2
        "bullish"
      elsif price_change < -2
        "bearish"
      else
        "neutral"
      end

      signal = if price_change > 5
        "buy"
      elsif price_change < -5
        "sell"
      else
        "hold"
      end

      {
        success: true,
        asset_id: asset.id,
        symbol: asset.symbol,
        trend_direction: trend,
        trading_signal: signal,
        confidence: "low",
        analysis: "Basic analysis based on price movement",
        timestamp: Time.current.iso8601
      }
    end

    # Build empty trading signals
    def build_empty_signals
      {
        trend_direction: "neutral",
        current_price: nil,
        avg_price: nil,
        sma_24: nil,
        support_level: nil,
        resistance_level: nil,
        volume_avg: nil,
        timestamp: Time.current.iso8601
      }
    end
  end
end
