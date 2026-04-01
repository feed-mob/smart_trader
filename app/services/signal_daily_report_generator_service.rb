# frozen_string_literal: true

# 信号日报生成服务
class SignalDailyReportGeneratorService
  SIGNAL_REPORT_INSTRUCTIONS = <<~INSTRUCTIONS.freeze
    你是一个专业的交易信号分析助手，负责生成每日交易信号日报。

    日报格式要求：
    1. 使用 Markdown 格式
    2. 包含以下章节：
       - 今日信号概览（总体信号分布）
       - 强买入/卖出信号（高置信度信号）
       - 重点关注资产（信号变化明显的资产）
       - 行业/板块信号分布
       - 风险提示

    语言风格：
    - 专业、客观、谨慎
    - 使用中文输出
    - 强调风险提示
  INSTRUCTIONS

  def initialize(date: Date.current)
    @date = date
    @ai_service = AiChatService.new(
      instructions: SIGNAL_REPORT_INSTRUCTIONS,
      temperature: 0.5,
      max_tokens: 2000
    )
  end

  def generate
    start_time = Time.current
    data = collect_data

    # 如果没有信号数据，生成一个空日报
    if data[:signals].empty?
      content = build_empty_report
      summary = "今日暂无交易信号数据"
      return save_report(content, summary, data, start_time)
    end

    prompt = build_prompt(data)
    content = @ai_service.ask(prompt)
    summary = generate_summary(content)
    save_report(content, summary, data, start_time)
  rescue StandardError => e
    Rails.logger.error("SignalDailyReportGeneratorService Error: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    nil
  end

  private

  def collect_data
    # 获取当天生成的信号
    signals = TradingSignal.where("DATE(generated_at) = ?", @date)
                          .includes(:asset)
                          .order(generated_at: :desc)

    {
      date: @date,
      signals: signals,
      latest_signals: TradingSignal.includes(:asset)
                                 .select("DISTINCT ON (asset_id) trading_signals.*")
                                 .where("DATE(generated_at) <= ?", @date)
                                 .order("asset_id, generated_at DESC")
    }
  end

  def build_prompt(data)
    signals = data[:signals]
    stats = calculate_stats(signals)

    <<~PROMPT
      请基于以下数据生成 #{@date.strftime('%Y-%m-%d')} 的交易信号分析日报：

      ## 信号统计
      - 总信号数: #{stats[:total]}
      - 买入信号: #{stats[:buy]}
      - 卖出信号: #{stats[:sell]}
      - 持有信号: #{stats[:hold]}
      - 高置信度: #{stats[:high_confidence]}

      ## 强信号资产（置信度 >= 70%）
      #{strong_signals_list(signals)}

      ## 详细信号数据（前30条）
      #{signals_data_formatted(signals.take(30))}

      请按照指令要求的格式生成日报。
    PROMPT
  end

  def calculate_stats(signals)
    {
      total: signals.count,
      buy: signals.count { |s| s.buy? },
      sell: signals.count { |s| s.sell? },
      hold: signals.count { |s| s.hold? },
      high_confidence: signals.count { |s| s.confidence.to_f >= 0.7 }
    }
  end

  def strong_signals_list(signals)
    strong = signals.select { |s| s.confidence.to_f >= 0.7 }.take(10)

    return "无" if strong.empty?

    strong.map do |s|
      "#{s.asset.symbol} | #{s.signal_type_label} | 置信度: #{s.confidence_percentage}% | #{truncate_text(s.reasoning, 50)}"
    end.join("\n")
  end

  def signals_data_formatted(signals)
    return "无数据" if signals.empty?

    signals.map do |s|
      confidence_display = s.confidence.nil? ? 'N/A' : "#{s.confidence_percentage}%"
      "#{s.asset.symbol} | #{s.signal_type_label} | 置信度: #{confidence_display} | #{truncate_text(s.reasoning, 60)}"
    end.join("\n")
  end

  def truncate_text(text, length)
    return '' if text.nil?
    text.length > length ? "#{text[0, length]}..." : text
  end

  def save_report(content, summary, data, start_time)
    generation_time_ms = ((Time.current - start_time) * 1000).to_i

    report = DailyReport.find_or_initialize_by(
      report_type: 'signal',
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
    signals = data[:signals]
    stats = calculate_stats(signals)
    latest_signals = data[:latest_signals]

    # 按信号类型统计最新信号
    latest_stats = {
      total: latest_signals.count,
      buy: latest_signals.count { |s| s.buy? },
      sell: latest_signals.count { |s| s.sell? },
      hold: latest_signals.count { |s| s.hold? }
    }

    stats.merge(latest_signals: latest_stats, report_date: @date.to_s)
  end

  def generate_summary(content)
    lines = content.split("\n").map(&:strip).reject(&:empty?)
    # 找到第一个非标题行
    first_non_header = lines.find { |l| !l.start_with?('#') }
    first_non_header || lines.first || "暂无摘要"
  end

  def build_empty_report
    <<~MARKDOWN
      # #{@date.strftime('%Y年%m月%d日')} 交易信号日报

      ## 今日信号概览

      **暂无交易信号数据**

      请先生成交易信号后再查看日报。

      ## 风险提示

      - 当前日期 #{@date.strftime('%Y-%m-%d')} 没有可用的交易信号
      - 建先生成交易信号，日报将包含详细分析
    MARKDOWN
  end
end
