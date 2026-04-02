# frozen_string_literal: true

# 因子日报生成服务
class FactorDailyReportGeneratorService
  FACTOR_REPORT_INSTRUCTIONS = <<~INSTRUCTIONS.freeze
    你是一个专业的金融数据分析助手，负责生成每日因子分析日报。

    日报格式要求：
    1. 使用 Markdown 格式
    2. 包含以下章节：
       - 今日概览（简要总结当日因子表现）
       - 重点因子分析（突出表现异常或趋势明显的因子）
       - 分行业/分类因子表现
       - 历史对比（与昨日/上周对比，如果数据足够）
       - 建议与洞察

    语言风格：
    - 专业、简洁、数据驱动
    - 使用中文输出
    - 突出关键数据和变化趋势
  INSTRUCTIONS

  def initialize(date: Date.current)
    @date = date
    @ai_service = AiChatService.new(
      instructions: FACTOR_REPORT_INSTRUCTIONS,
      temperature: 0.5,
      max_tokens: 2000
    )
  end

  def generate
    start_time = Time.current

    # 收集数据
    data = collect_data

    # 如果没有因子数据，生成一个空日报
    if data[:factors].empty?
      content = build_empty_report
      summary = "今日暂无因子数据"
      return save_report(content, summary, data, start_time)
    end

    # 构建 prompt
    prompt = build_prompt(data)

    # 调用 AI 生成
    content = @ai_service.ask(prompt)

    # 生成摘要
    summary = generate_summary(content)

    # 保存日报
    save_report(content, summary, data, start_time)
  rescue StandardError => e
    Rails.logger.error("FactorDailyReportGeneratorService Error: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    nil
  end

  private

  def collect_data
    {
      date: @date,
      factors: FactorDefinition.active.ordered.to_a,
      factor_values: FactorValue.where(calculated_at: @date.beginning_of_day...(@date + 1.day).beginning_of_day)
                              .includes(:asset, :factor_definition)
    }
  end

  def build_prompt(data)
    # 格式化数据供 AI 分析
    formatted_data = format_data_for_ai(data)

    <<~PROMPT
      请基于以下数据生成 #{@date.strftime('%Y-%m-%d')} 的交易因子分析日报：

      ## 数据统计
      - 活跃因子数量: #{data[:factors].count}
      - 因子值记录数: #{data[:factor_values].count}

      ## 因子分类统计
      #{factor_category_stats(data)}

      ## 因子表现数据（前50条记录）
      #{formatted_data}

      请按照指令要求的格式生成日报。
    PROMPT
  end

  def format_data_for_ai(data)
    values = data[:factor_values].take(50)

    values.map do |fv|
      factor = fv.factor_definition
      asset = fv.asset
      value_display = fv.normalized_value.nil? ? 'N/A' : fv.normalized_value.round(4)
      percentile_display = fv.percentile.nil? ? 'N/A' : fv.percentile.round(1)

      "#{asset.symbol} | #{factor.code}(#{factor.name}) | 标准化值: #{value_display} | 百分位: #{percentile_display}%"
    end.join("\n")
  end

  def factor_category_stats(data)
    categories = data[:factors].group_by(&:category)
    categories.map do |cat, factors|
      "#{FactorDefinition::CATEGORIES[cat]}: #{factors.count}个因子"
    end.join("\n")
  end

  def save_report(content, summary, data, start_time)
    generation_time_ms = ((Time.current - start_time) * 1000).to_i

    report = DailyReport.find_or_initialize_by(
      report_type: 'factor',
      report_date: @date
    )

    report.assign_attributes(
      content: content,
      summary: summary,
      statistics: build_statistics(data),
      generated_by: 'ai',
      model_version: AiChatService::MODEL,
      generation_time_ms: generation_time_ms
    )

    report.save!
    report
  end

  def build_statistics(data)
    {
      total_factors: data[:factors].count,
      active_factors: data[:factors].count(&:active?),
      total_assets: data[:factor_values].select(:asset_id).distinct.count,
      factor_categories: data[:factors].group_by(&:category).transform_values(&:count),
      total_values: data[:factor_values].count,
      report_date: @date.to_s
    }
  end

  def generate_summary(content)
    lines = content.split("\n").map(&:strip).reject(&:empty?)
    # 找到第一个非标题行
    first_non_header = lines.find { |l| !l.start_with?('#') }
    first_non_header || lines.first || "暂无摘要"
  end

  def build_empty_report
    <<~MARKDOWN
      # #{@date.strftime('%Y年%m月%d日')} 交易因子日报

      ## 今日概览

      **暂无因子数据**

      请先添加因子后再查看日报。

      ## 建议与洞察

      - 当前日期 #{@date.strftime('%Y-%m-%d')} 没有可用的因子数据
      - 建议在因子管理页面添加交易因子
    MARKDOWN
  end
end
