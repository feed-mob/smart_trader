# frozen_string_literal: true

module Admin
  class TradingSignalsController < ApplicationController
    before_action :require_user
    before_action :set_signal, only: %i[show]

    def index
      @signals = TradingSignal.includes(:asset)
                              .recent
                              .page(params[:page])
                              .per(20)

      # 筛选
      @signals = @signals.by_signal_type(params[:signal_type]) if params[:signal_type].present?
      @signals = @signals.where(asset_id: params[:asset_id]) if params[:asset_id].present?

      # 获取每个资产的最新信号
      @latest_signals = TradingSignal.includes(:asset)
                                     .select("DISTINCT ON (asset_id) trading_signals.*")
                                     .order("asset_id, generated_at DESC")

      # 统计
      @stats = {
        total: TradingSignal.count,
        buy: TradingSignal.buy_signals.count,
        sell: TradingSignal.sell_signals.count,
        hold: TradingSignal.hold_signals.count,
        high_confidence: TradingSignal.high_confidence.count
      }
    end

    def show; end

    def generate
      asset = Asset.find(params[:asset_id])
      service = SignalGeneratorService.new(asset)
      signal = service.generate_and_save!

      if signal
        redirect_to admin_trading_signal_path(signal), notice: "信号生成成功"
      else
        redirect_to admin_trading_signals_path, alert: "信号生成失败，请检查因子数据"
      end
    end

    def generate_all
      GenerateSignalsJob.perform_later
      redirect_to admin_trading_signals_path, notice: "正在后台生成信号，请稍后刷新页面"
    end

    private

    def set_signal
      @signal = TradingSignal.includes(:asset).find(params[:id])
    end
  end
end
