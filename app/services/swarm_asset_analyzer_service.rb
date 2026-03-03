# frozen_string_literal: true

# Swarm Asset Analyzer Service - Uses multi-agent system for comprehensive asset analysis
# Integrates trend analysis, signal generation, and risk assessment

class SwarmAssetAnalyzerService
  class << self
    # Load and run the asset analyzer swarm
    # @param asset [Asset] The asset to analyze
    # @return [Hash] Comprehensive analysis results
    def analyze(asset)
      Rails.logger.info "[SwarmAssetAnalyzer] Starting multi-agent analysis for #{asset.symbol}"

      # Prepare asset data for analysis
      asset_context = build_asset_context(asset)

      # Construct analysis prompt
      prompt = build_analysis_prompt(asset, asset_context)

      # Load and execute swarm
      result = execute_swarm_analysis(prompt)

      # Format and return results
      format_analysis_result(asset, result)
    rescue StandardError => e
      Rails.logger.error "[SwarmAssetAnalyzer] Analysis failed for #{asset.symbol}: #{e.message}"
      error_result(asset, e.message)
    end

    # Batch analyze multiple assets
    # @param assets [Array<Asset>] Assets to analyze
    # @return [Hash] Batch analysis results
    def analyze_batch(assets)
      results = {}

      assets.each do |asset|
        begin
          results[asset.symbol] = analyze(asset)
        rescue StandardError => e
          results[asset.symbol] = { error: e.message }
        end
      end

      {
        success: true,
        data: results,
        count: results.size,
        timestamp: Time.current.iso8601
      }
    end

    # Generate quick trading signal (lightweight, no LLM)
    # @param asset [Asset] The asset to analyze
    # @return [Hash] Trading signal based on technical indicators
    def quick_signal(asset)
      Rails.logger.info "[SwarmAssetAnalyzer] Generating quick signal for #{asset.symbol}"

      # Use simple technical analysis without LLM
      AIDataAnalyzerService.generate_trading_signals(asset)
    rescue StandardError => e
      Rails.logger.error "[SwarmAssetAnalyzer] Quick signal failed: #{e.message}"
      { error: e.message }
    end

    private

    # Build asset context for swarm
    def build_asset_context(asset)
      recent_snapshots = asset.asset_snapshots.recent(48)

      if recent_snapshots.empty?
        return build_empty_context(asset)
      end

      prices = recent_snapshots.pluck(:price)

      {
        symbol: asset.symbol,
        name: asset.name,
        asset_type: asset.asset_type,
        current_price: prices.last,
        recent_snapshots_count: recent_snapshots.count,
        price_data: recent_snapshots.map do |s|
          {
            timestamp: s.captured_at.strftime('%Y-%m-%d %H:%M'),
            price: s.price,
            volume: s.volume,
            change_percent: s.change_percent
          }
        end,
        statistics: {
          min_price: prices.min,
          max_price: prices.max,
          avg_price: (prices.sum / prices.size).round(2),
          price_range: prices.max - prices.min,
          volatility: calculate_volatility(prices)
        }
      }
    end

    # Build empty context
    def build_empty_context(asset)
      {
        symbol: asset.symbol,
        name: asset.name,
        asset_type: asset.asset_type,
        current_price: asset.current_price,
        recent_snapshots_count: 0,
        price_data: [],
        statistics: {},
        note: "No historical data available"
      }
    end

    # Calculate price volatility
    def calculate_volatility(prices)
      return 0 if prices.size < 2

      # Simple standard deviation calculation
      mean = prices.sum / prices.size
      variance = prices.sum { |p| (p - mean) ** 2 } / prices.size
      Math.sqrt(variance).round(2)
    end

    # Build analysis prompt for swarm
    def build_analysis_prompt(asset, context)
      stats = context[:statistics]
      note = context[:note] || ""

      <<~PROMPT
        Analyze the asset #{context[:name]} (#{context[:symbol]}):

        **Asset Information**:
        - Type: #{context[:asset_type]}
        - Current Price: $#{context[:current_price]}

        **Market Data** (Last #{context[:recent_snapshots_count]} snapshots):
        - Price Range: $#{stats[:min_price]} - $#{stats[:max_price]}
        - Average Price: $#{stats[:avg_price]}
        - Price Range: $#{stats[:price_range]}
        - Volatility: #{stats[:volatility]}

        **Task**:
        Please provide a comprehensive analysis including:
        1. Trend direction and strength
        2. Support and resistance levels
        3. Trading signal (buy/sell/hold) with confidence
        4. Risk assessment
        5. Recommended entry/exit points

        #{note}

        Return results as structured JSON.
      PROMPT
    end

    # Execute swarm analysis
    def execute_swarm_analysis(prompt)
      # Load swarm configuration
      config_path = Rails.root.join("config", "swarms", "asset_analyzer.yml")

      Rails.logger.info "[SwarmAssetAnalyzer] Loading swarm from #{config_path}"

      # Check if SwarmSDK is available
      unless defined?(SwarmSDK)
        Rails.logger.warn "[SwarmAssetAnalyzer] SwarmSDK not available, returning fallback"
        return { error: "SwarmSDK not configured" }
      end

      # Create a simple agent for analysis
      swarm = SwarmSDK::Swarm.new(
        name: "AssetAnalysis",
        lead: SwarmSDK::Agent.new(
          name: "analyzer",
          description: "Performs comprehensive asset analysis",
          model: "claude-sonnet-4",
          system_prompt: build_simple_system_prompt
        )
      )

      # Execute the analysis
      result = swarm.execute(prompt)

      Rails.logger.info "[SwarmAssetAnalyzer] Swarm execution completed"

      result
    rescue LoadError => e
      Rails.logger.error "[SwarmAssetAnalyzer] Failed to load SwarmSDK: #{e.message}"
      { error: "SwarmSDK not available" }
    end

    # Simple system prompt for single agent fallback
    def build_simple_system_prompt
      <<~PROMPT
        You are a Financial Market Analyst. Your role is to:
        1. Analyze the provided market data
        2. Identify trends, support/resistance levels
        3. Generate trading signals with confidence levels
        4. Assess risk factors
        5. Provide actionable recommendations

        Always be objective, conservative with risk, and clearly explain your reasoning.
        Return results in JSON format.
      PROMPT
    end

    # Format analysis result
    def format_analysis_result(asset, result)
      if result[:error]
        return error_result(asset, result[:error])
      end

      # Try to extract JSON from result
      content = extract_content(result)

      {
        success: true,
        asset_id: asset.id,
        symbol: asset.symbol,
        analysis_result: content,
        timestamp: Time.current.iso8601
      }
    end

    # Extract content from swarm result
    def extract_content(result)
      if result[:message]
        result[:message]
      elsif result[:content]
        result[:content]
      elsif result[:result]
        result[:result]
      else
        result.to_s
      end
    end

    # Build error result
    def error_result(asset, error_message)
      {
        success: false,
        asset_id: asset.id,
        symbol: asset.symbol,
        error: error_message,
        timestamp: Time.current.iso8601
      }
    end
  end
end
