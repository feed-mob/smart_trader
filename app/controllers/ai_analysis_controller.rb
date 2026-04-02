# frozen_string_literal: true

class AiAnalysisController < ApplicationController
  before_action :require_user

  def new
    @default_assets = "BTC, ETH"
  end

  def create
    @assets_input = params[:assets] || "BTC, ETH"
    @analysis_type = params[:analysis_type] || "full"

    # 解析资产列表
    @assets = @assets_input.split(/[,\s]+/).map(&:strip).map(&:upcase).reject(&:empty?)

    if @assets.empty?
      flash[:alert] = "Please enter at least one asset"
      redirect_to new_ai_analysis_path and return
    end

    # Execute analysis (no longer depends on Trader)
    @result = perform_analysis(@assets, @analysis_type)

    # Store result in Rails.cache for show page
    result_cache_key = "ai_analysis_result_#{Time.current.to_i}"
    Rails.cache.write(result_cache_key, @result, expires_in: 10.minutes)

    flash[:notice] = "Analysis completed! Analyzed #{@assets.length} assets"
    redirect_to ai_analysis_result_path(result_key: result_cache_key, assets: @assets.join(","))
  end

  def show
    @result = Rails.cache.read(params[:result_key]) || {}
    @assets = params[:assets]&.split(",") || []
    @logs = @result[:logs] || []
    @analysis_type = "full"
  end

  def quick_analysis
    @assets = params[:assets]&.split(/[,\s]+/)&.map(&:upcase) || ["BTC", "ETH"]
    @capital = params[:capital]&.to_f || 100_000
    @risk_preference = params[:risk_preference] || "balanced"

    # 使用新的独立分析服务
    service = AiAllocationServiceV2.new(
      symbols: @assets,
      capital: @capital,
      risk_preference: @risk_preference
    )
    @result = service.run_full_pipeline

    render json: {
      success: true,
      assets: @assets,
      logs: @result[:logs],
      signals: @result[:signals],
      recommendation: @result[:recommendation]
    }
  rescue => e
    render json: {
      success: false,
      error: e.message,
      backtrace: e.backtrace.first(5)
    }
  end

  private

  def perform_analysis(assets, analysis_type)
    log "=" * 80
    log "[AiAnalysis] 开始分析: #{assets.join(', ')}"
    log "[AiAnalysis] 分析类型: #{analysis_type}"
    log "=" * 80

    # 使用独立的 AiAllocationServiceV2
    service = AiAllocationServiceV2.new(
      symbols: assets,
      capital: 100_000,
      risk_preference: "balanced"
    )
    result = service.run_full_pipeline

    log "=" * 80
    log "[AiAnalysis] 分析完成!"
    log "=" * 80

    result
  end

  def log(message)
    Rails.logger.info message
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
end