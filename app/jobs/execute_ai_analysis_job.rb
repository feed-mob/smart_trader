# frozen_string_literal: true

class ExecuteAiAnalysisJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 2

  def perform(record_id)
    record = AiAnalysisRecord.find(record_id)

    record.update!(status: AiAnalysisRecord::STATUS_RUNNING, started_at: Time.current)

    files = record.files_list
    temp_file_paths = download_uploaded_files(record)
    all_file_paths = temp_file_paths + files

    prompt = build_single_turn_prompt(record.prompt)

    service = ClaudeCodeService.new
    result = service.ask_with_files(
      prompt,
      files: all_file_paths,
      permission_mode: "acceptEdits"
    )

    record.update!(
      output: result[:output],
      error: result[:error],
      status: result[:success] ? AiAnalysisRecord::STATUS_COMPLETED : AiAnalysisRecord::STATUS_FAILED,
      finished_at: Time.current
    )
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[ExecuteAiAnalysisJob] Record not found: #{e.message}"
  ensure
    cleanup_temp_files
  end

  private

  attr_reader :temp_files

  def build_single_turn_prompt(prompt)
    <<~PROMPT
      你正在通过一个 Rails 页面被程序调用。
      请一次性直接完成用户请求，不要反问，不要等待确认。
      如果信息不足，请自行做合理假设，并明确写出你的假设。

      用户请求：
      #{prompt}
    PROMPT
  end

  def download_uploaded_files(record)
    return [] unless record.uploaded_files.attached?

    @temp_files ||= []

    record.uploaded_files.map do |attachment|
      ext = File.extname(attachment.filename.to_s)
      basename = File.basename(attachment.filename.to_s, ext)
      temp_file = Tempfile.new([ basename, ext ])
      temp_file.binmode
      temp_file.write(attachment.download)
      temp_file.flush
      @temp_files << temp_file
      temp_file.path
    end
  end

  def cleanup_temp_files
    @temp_files&.each(&:unlink)
  end
end
