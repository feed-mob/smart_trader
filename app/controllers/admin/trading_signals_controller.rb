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

      # Filter
      @signals = @signals.by_signal_type(params[:signal_type]) if params[:signal_type].present?
      @signals = @signals.where(asset_id: params[:asset_id]) if params[:asset_id].present?

      # Get latest signal for each asset
      @latest_signals = TradingSignal.includes(:asset)
                                     .select("DISTINCT ON (asset_id) trading_signals.*")
                                     .order("asset_id, generated_at DESC")

      # Statistics
      @stats = {
        total: TradingSignal.count,
        buy: TradingSignal.buy_signals.count,
        sell: TradingSignal.sell_signals.count,
        hold: TradingSignal.hold_signals.count,
        high_confidence: TradingSignal.high_confidence.count
      }

      # Get latest signal daily report
      @latest_report = DailyReport.latest_for_type('signal')
    end

    def show; end

    def generate
      asset = Asset.find(params[:asset_id])
      service = SignalGeneratorService.new(asset)
      signal = service.generate_and_save!

      if signal
        redirect_to admin_trading_signal_path(signal), notice: "Signal generated successfully"
      else
        redirect_to admin_trading_signals_path, alert: "Signal generation failed, please check factor data"
      end
    end

    def generate_all
      GenerateSignalsJob.perform_later
      redirect_to admin_trading_signals_path, notice: "Signals are being generated in background, please refresh later"
    end

    private

    def set_signal
      @signal = TradingSignal.includes(:asset).find(params[:id])
    end
  end
end
