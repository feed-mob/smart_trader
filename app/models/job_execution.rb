# frozen_string_literal: true

class JobExecution < ApplicationRecord
  # 状态常量
  STATUS_RUNNING = "running"
  STATUS_SUCCESS = "success"
  STATUS_FAILED = "failed"

  validates :job_id, presence: true, uniqueness: true
  validates :job_name, presence: true
  validates :status, presence: true, inclusion: { in: [ STATUS_RUNNING, STATUS_SUCCESS, STATUS_FAILED ] }
  validates :started_at, presence: true

  # 作用域
  scope :by_job_name, ->(name) { where(job_name: name) if name.present? }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :recent_first, -> { order(started_at: :desc) }
  scope :in_date_range, ->(start_date, end_date) {
    where(started_at: start_date..end_date) if start_date.present? && end_date.present?
  }

  # 计算执行时长（秒）
  def duration_seconds
    return nil unless duration_ms
    (duration_ms / 1000.0).round(2)
  end

  # 格式化执行时长
  def formatted_duration
    return "-" unless duration_ms

    if duration_ms < 1000
      "#{duration_ms}ms"
    elsif duration_ms < 60000
      "#{(duration_ms / 1000.0).round(1)}s"
    else
      minutes = (duration_ms / 60000).to_i
      seconds = ((duration_ms % 60000) / 1000.0).round(1)
      "#{minutes}m #{seconds}s"
    end
  end

  # 格式化参数显示
  def formatted_arguments
    return "-" unless arguments.present?

    parsed = JSON.parse(arguments) rescue nil
    return "-" unless parsed

    if parsed.is_a?(Hash)
      parsed.map { |k, v| "#{k}: #{v}" }.join(", ")
    else
      parsed.to_s
    end
  end

  # 标记为成功
  def mark_success!
    now = Time.current
    update!(
      status: STATUS_SUCCESS,
      finished_at: now,
      duration_ms: ((now - started_at) * 1000).to_i
    )
  end

  # 标记为失败
  def mark_failed!(error_message)
    now = Time.current
    update!(
      status: STATUS_FAILED,
      finished_at: now,
      duration_ms: ((now - started_at) * 1000).to_i,
      error_message: error_message
    )
  end
end
