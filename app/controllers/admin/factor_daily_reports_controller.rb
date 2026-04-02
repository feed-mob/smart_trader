# frozen_string_literal: true

module Admin
  class FactorDailyReportsController < ApplicationController
    before_action :require_user
    before_action :set_report, only: %i[show edit update destroy regenerate]

    REPORT_TYPE = 'factor'.freeze

    def index
      @reports = DailyReport.factor_reports
                          .recent
                          .page(params[:page])
                          .per(20)
    end

    def show
      @report.update!(published: true) unless @report.published?
    end

    def new
      @report = DailyReport.new(report_type: REPORT_TYPE)
    end

    def create
      @report = DailyReport.new(report_params.merge(report_type: REPORT_TYPE))

      if @report.save
        redirect_to admin_factor_daily_report_path(@report), notice: '日报创建成功'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @report.update(report_params)
        redirect_to admin_factor_daily_report_path(@report), notice: '日报更新成功'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @report.destroy
      redirect_to admin_factor_daily_reports_path, notice: '日报已删除'
    end

    # 手动生成日报
    def generate
      date = params[:date]&.to_date || Date.current

      # 检查是否已存在
      existing = DailyReport.find_by(report_type: REPORT_TYPE, report_date: date)
      if existing
        redirect_to admin_factor_daily_report_path(existing), alert: '该日期的日报已存在'
        return
      end

      GenerateFactorDailyReportJob.perform_now(date:)
      report = DailyReport.find_by(report_type: REPORT_TYPE, report_date: date)

      if report
        redirect_to admin_factor_daily_report_path(report), notice: '日报生成成功'
      else
        redirect_to admin_factor_daily_reports_path, alert: '日报生成失败'
      end
    end

    # 重新生成日报
    def regenerate
      date = @report.report_date
      GenerateFactorDailyReportJob.perform_now(date:)
      report = DailyReport.find_by(report_type: REPORT_TYPE, report_date: date)

      if report
        redirect_to admin_factor_daily_report_path(report), notice: '日报重新生成成功'
      else
        redirect_to admin_factor_daily_report_path(@report), alert: '日报重新生成失败'
      end
    end

    private

    def set_report
      @report = DailyReport.find(params[:id])
    end

    def report_params
      params.require(:daily_report).permit(
        :content,
        :summary,
        :published
      )
    end
  end
end
