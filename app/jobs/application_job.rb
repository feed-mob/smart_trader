# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Job 执行追踪
  around_perform :track_execution

  private

  def track_execution
    # 创建执行记录
    execution = JobExecution.find_or_initialize_by(job_id: job_id)
    execution.assign_attributes(
      job_name: self.class.name,
      status: JobExecution::STATUS_RUNNING,
      started_at: Time.current,
      arguments: format_job_arguments,
      queue_name: queue_name
    )
    execution.save!

    begin
      yield
      execution.mark_success!
    rescue => e
      execution.mark_failed!(e.message)
      # 不重新抛出异常，记录错误但让 job 正常结束
    end
  end

  def format_job_arguments
    return nil if arguments.blank?

    # 安全序列化参数
    arguments.map do |arg|
      if arg.is_a?(GlobalID::Identification)
        { "_type" => arg.class.name, "id" => arg.id }
      elsif arg.is_a?(Hash) || arg.is_a?(Array) || arg.is_a?(String) || arg.is_a?(Numeric)
        arg
      else
        arg.to_s
      end
    end.to_json
  rescue => e
    { error: "Failed to serialize arguments: #{e.message}" }.to_json
  end
end
