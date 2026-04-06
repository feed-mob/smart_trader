# frozen_string_literal: true

class AiAnalysisRecord < ApplicationRecord
  belongs_to :user
  has_many_attached :uploaded_files

  # Status constants
  STATUS_PENDING = "pending"
  STATUS_RUNNING = "running"
  STATUS_COMPLETED = "completed"
  STATUS_FAILED = "failed"

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: STATUS_COMPLETED) }
  scope :failed, -> { where(status: STATUS_FAILED) }

  # Validations
  validates :prompt, presence: true
  validates :status, inclusion: { in: [ STATUS_PENDING, STATUS_RUNNING, STATUS_COMPLETED, STATUS_FAILED ] }

  # Instance methods
  def pending?
    status == STATUS_PENDING
  end

  def running?
    status == STATUS_RUNNING
  end

  def success?
    status == STATUS_COMPLETED
  end

  def failed?
    status == STATUS_FAILED
  end

  def finished?
    status.in?([ STATUS_COMPLETED, STATUS_FAILED ])
  end

  def files_list
    text_paths = files.blank? ? [] : files.split(/[\n,]+/).map(&:strip).reject(&:blank?)
    uploaded_names = uploaded_files.map { |f| f.filename.to_s }
    text_paths + uploaded_names
  end

  def truncated_prompt(length = 100)
    return "" if prompt.blank?
    prompt.length > length ? "#{prompt[0..length]}..." : prompt
  end

  def duration_text
    return nil unless started_at && finished_at
    duration = finished_at - started_at
    if duration < 60
      "#{duration.round(1)}s"
    else
      minutes = (duration / 60).floor
      seconds = (duration % 60).round
      "#{minutes}m #{seconds}s"
    end
  end

  def output
    self[:output]
  end

  def error
    self[:error]
  end
end
