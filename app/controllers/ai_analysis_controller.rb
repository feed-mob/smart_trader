# frozen_string_literal: true

class AiAnalysisController < ApplicationController
  before_action :require_user
  before_action :set_record, only: [ :show ]

  def index
    @records = current_user.ai_analysis_records.recent.page(params[:page]).per(20)
  end

  def new
    @default_prompt = ""
    @default_files = ""
  end

  def create
    @prompt = params[:prompt].to_s.strip
    @files_input = params[:files].to_s
    @permission_mode = params[:permission_mode].presence || "default"

    if @prompt.blank?
      flash[:alert] = "请输入要发送给 Claude Code 的 prompt"
      redirect_to new_ai_analysis_path and return
    end

    record = current_user.ai_analysis_records.create!(
      prompt: @prompt,
      files: @files_input,
      permission_mode: @permission_mode,
      status: AiAnalysisRecord::STATUS_PENDING
    )

    uploaded_files = params.dig(:ai_analysis_record, :uploaded_files)
    if uploaded_files.present?
      Array(uploaded_files).each do |file|
        record.uploaded_files.attach(file) if file.present?
      end
    end

    ExecuteAiAnalysisJob.perform_later(record.id)

    redirect_to ai_analysis_path(id: record.id)
  end

  def show
    @prompt = @record.prompt
    @files = @record.files_list
    @permission_mode = @record.permission_mode
    @result = {
      success: @record.success?,
      output: @record.output,
      error: @record.error
    }
  end

  def status
    record = current_user.ai_analysis_records.find(params[:id])
    render json: {
      status: record.status,
      finished: record.finished?,
      output: record.output,
      error: record.error
    }
  end

  private

  def set_record
    @record = current_user.ai_analysis_records.find(params[:id])
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
end
