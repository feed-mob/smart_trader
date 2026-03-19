# frozen_string_literal: true

class DailyReport < ApplicationRecord
  # 常量定义
  REPORT_TYPES = {
    'factor' => '因子日报',
    'signal' => '信号日报'
  }.freeze

  # 验证
  validates :report_type, presence: true, inclusion: { in: REPORT_TYPES.keys }
  validates :report_date, presence: true
  validates :content, presence: true

  # Scopes
  scope :factor_reports, -> { where(report_type: 'factor') }
  scope :signal_reports, -> { where(report_type: 'signal') }
  scope :published, -> { where(published: true) }
  scope :draft, -> { where(published: false) }
  scope :recent, -> { order(report_date: :desc, created_at: :desc) }

  # 类方法
  def self.types_for_select
    REPORT_TYPES.map { |key, name| [name, key] }
  end

  def self.latest_for_type(report_type)
    where(report_type: report_type).recent.first
  end

  # 实例方法
  def type_label
    REPORT_TYPES[report_type]
  end

  def factor_report?
    report_type == 'factor'
  end

  def signal_report?
    report_type == 'signal'
  end

  def published_label
    published? ? '已发布' : '草稿'
  end
end
