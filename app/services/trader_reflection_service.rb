# frozen_string_literal: true

class TraderReflectionService
  PROMPT_VERSION = "v1"

  def initialize(trader, period_start: 30.days.ago.to_date, period_end: Date.current)
    @trader = trader
    @period_start = period_start
    @period_end = period_end
  end

  def call
    reflection = @trader.trader_reflections.find_or_initialize_by(
      reflection_period_start: @period_start,
      reflection_period_end: @period_end
    )

    reflection.assign_attributes(
      trading_strategy: @trader.default_strategy,
      status: :pending,
      source: llm_available? ? "llm" : "fallback",
      prompt_version: PROMPT_VERSION,
      metrics: metrics_payload,
      findings: {},
      suggested_adjustments: [],
      error_message: nil
    )
    reflection.save!

    parsed = llm_available? ? generate_with_llm : fallback_report

    reflection.update!(
      status: :generated,
      llm_summary: parsed[:summary],
      findings: parsed[:findings],
      suggested_adjustments: parsed[:suggested_adjustments],
      generated_at: Time.current
    )

    reflection
  rescue StandardError => e
    reflection&.update(status: :failed, error_message: e.message)
    raise
  end

  private

  def llm_available?
    ENV["OPENAI_API_KEY"].present? && ENV["OPENAI_API_BASE"].present?
  end

  def generate_with_llm
    response = reflection_agent.ask(prompt)

    parsed = parse_json(response.content)

    {
      summary: parsed["summary"].presence || fallback_report[:summary],
      findings: {
        "strengths" => Array(parsed["strengths"]).compact,
        "mistakes" => Array(parsed["mistakes"]).compact,
        "pattern_findings" => Array(parsed["pattern_findings"]).compact,
        "risk_issues" => Array(parsed["risk_issues"]).compact,
        "recommendation" => parsed["recommendation"].to_s
      },
      suggested_adjustments: Array(parsed["suggested_adjustments"]).compact
    }
  rescue StandardError
    fallback_report
  end

  def parse_json(content)
    clean = content.to_s.gsub(/```json\s*|\s*```/i, "").strip
    json_match = clean.match(/\{.*\}/m)
    JSON.parse(json_match ? json_match[0] : clean)
  end

  def fallback_report
    metrics = metrics_payload
    total_profit_loss = metrics["total_profit_loss"].to_d
    trade_count = metrics["trade_count"].to_i
    risk_issues = []
    risk_issues << "近期交易次数偏少，样本有限，结论置信度较低。" if trade_count < 3
    risk_issues << "当前持仓浮亏较大，需复核入场时机与仓位控制。" if metrics["unrealized_pnl"].to_d < -1000

    {
      summary: if total_profit_loss.positive?
                 "最近一段时间整体仍有盈利，但需要继续复核持仓质量与风险控制。"
               elsif total_profit_loss.zero?
                 "最近一段时间整体接近打平，说明策略尚未形成明显优势。"
               else
                 "最近一段时间整体表现偏弱，应优先复核买入门槛、仓位集中度和现金保留比例。"
               end,
      findings: {
        "strengths" => [
          "当前策略和交易执行链路完整，能够持续产出 recommendation 并落地执行。"
        ],
        "mistakes" => [
          "近期表现说明策略参数与市场环境之间可能存在错配。"
        ],
        "pattern_findings" => [
          "反思结果基于最近 30 天执行记录、交易流水、组合快照和当前持仓。"
        ],
        "risk_issues" => risk_issues,
        "recommendation" => "建议先阅读反思报告，再决定是否人工微调现有策略参数。"
      },
      suggested_adjustments: suggested_adjustments_from_metrics(metrics)
    }
  end

  def suggested_adjustments_from_metrics(metrics)
    adjustments = []

    if metrics["unrealized_pnl"].to_d < -1000
      adjustments << {
        "parameter" => "buy_signal_threshold",
        "direction" => "increase",
        "reason" => "近期持仓浮亏偏大，建议提高买入门槛，减少边际信号质量不足的入场。"
      }
    end

    if metrics["cash_ratio"].to_d < 0.1
      adjustments << {
        "parameter" => "min_cash_reserve",
        "direction" => "increase",
        "reason" => "当前现金比例偏低，建议提高现金保留，增强回撤期缓冲能力。"
      }
    end

    adjustments
  end

  def prompt
    <<~PROMPT
      请基于以下 trader 反思上下文，输出 JSON：

      #{JSON.pretty_generate(reflection_payload)}

      返回格式：
      {
        "summary": "string",
        "strengths": ["string"],
        "mistakes": ["string"],
        "pattern_findings": ["string"],
        "risk_issues": ["string"],
        "suggested_adjustments": [
          {
            "parameter": "max_positions|buy_signal_threshold|max_position_size|min_cash_reserve",
            "direction": "increase|decrease|keep",
            "reason": "string"
          }
        ],
        "recommendation": "string"
      }
    PROMPT
  end

  def reflection_agent
    @reflection_agent ||= TraderReflectionAgent.new
  end

  def reflection_payload
    {
      trader: {
        id: @trader.id,
        name: @trader.name,
        risk_level: @trader.risk_level,
        initial_capital: @trader.initial_capital.to_d.round(2).to_f
      },
      period: {
        start: @period_start.iso8601,
        end: @period_end.iso8601
      },
      strategy: strategy_payload,
      metrics: metrics_payload,
      recent_trades: trades_payload,
      recent_tasks: tasks_payload,
      current_positions: positions_payload
    }
  end

  def strategy_payload
    strategy = @trader.default_strategy
    return {} unless strategy

    {
      id: strategy.id,
      name: strategy.name,
      market_condition: strategy.market_condition,
      max_positions: strategy.max_positions,
      buy_signal_threshold: strategy.buy_signal_threshold.to_f,
      max_position_size: strategy.max_position_size.to_f,
      min_cash_reserve: strategy.min_cash_reserve.to_f
    }
  end

  def metrics_payload
    @metrics_payload ||= begin
      trades = scoped_trades.to_a
      tasks = scoped_tasks.to_a
      latest_snapshot = scoped_snapshots.max_by { |snapshot| [snapshot.snapshot_date, snapshot.captured_at] } ||
                        @trader.portfolio_snapshots.recent.first
      current_unrealized = current_unrealized_metrics
      latest_portfolio_value = latest_snapshot&.portfolio_value.to_d.nonzero? || @trader.current_capital_value.to_d
      total_profit_loss = if latest_snapshot.present?
                            latest_snapshot.profit_loss.to_d
                          else
                            (latest_portfolio_value - @trader.initial_capital.to_d).round(2)
                          end
      equity_value = latest_portfolio_value.to_d
      cash_value = latest_snapshot&.cash_value.to_d
      cash_ratio = equity_value.positive? ? (cash_value / equity_value).round(4) : 0.to_d

      {
        "trade_count" => trades.size,
        "buy_count" => trades.count { |trade| trade.action == "buy" },
        "sell_count" => trades.count { |trade| trade.action == "sell" },
        "completed_task_count" => tasks.count(&:completed?),
        "failed_task_count" => tasks.count(&:failed?),
        "total_buy_amount" => trades.select { |trade| trade.action == "buy" }.sum { |trade| trade.amount.to_d }.round(2).to_f,
        "total_sell_amount" => trades.select { |trade| trade.action == "sell" }.sum { |trade| trade.amount.to_d }.round(2).to_f,
        "latest_portfolio_value" => latest_portfolio_value.round(2).to_f,
        "total_profit_loss" => total_profit_loss.round(2).to_f,
        "total_profit_loss_percent" => if @trader.initial_capital.to_d.positive?
                                         ((total_profit_loss / @trader.initial_capital.to_d) * 100).round(2).to_f
                                       else
                                         0.0
                                       end,
        "cash_value" => cash_value.round(2).to_f,
        "cash_ratio" => cash_ratio.to_f,
        "unrealized_pnl" => current_unrealized[:unrealized_pnl].to_f,
        "unrealized_pnl_percent" => current_unrealized[:unrealized_pnl_percent].to_f,
        "position_count" => @trader.trader_positions.active.count
      }
    end
  end

  def current_unrealized_metrics
    unrealized_pnl = 0.to_d
    cost_basis = 0.to_d

    @trader.trader_positions.active.includes(:asset).each do |position|
      quantity = position.quantity.to_d
      latest_price = position.asset.latest_snapshot&.price&.to_d || position.current_price.to_d
      market_value = (quantity * latest_price).round(2)
      position_cost_basis = (quantity * position.average_cost.to_d).round(2)
      unrealized_pnl += market_value - position_cost_basis
      cost_basis += position_cost_basis
    end

    unrealized_pnl = unrealized_pnl.round(2)

    {
      unrealized_pnl: unrealized_pnl,
      unrealized_pnl_percent: cost_basis.positive? ? ((unrealized_pnl / cost_basis) * 100).round(2) : 0
    }
  end

  def trades_payload
    scoped_trades.limit(20).map do |trade|
      {
        executed_at: trade.executed_at&.iso8601,
        action: trade.action,
        symbol: trade.asset.symbol,
        amount: trade.amount.to_d.round(2).to_f,
        price: trade.price.to_d.round(2).to_f,
        reason: trade.reason
      }
    end
  end

  def tasks_payload
    scoped_tasks.limit(10).map do |task|
      {
        run_on: task.run_on&.iso8601,
        status: task.status,
        ending_cash: task.ending_cash.to_d.round(2).to_f,
        portfolio_value: task.portfolio_value.to_d.round(2).to_f,
        summary: task.summary
      }
    end
  end

  def positions_payload
    @trader.trader_positions.active.includes(:asset).ordered_by_value.limit(10).map do |position|
      latest_price = position.asset.latest_snapshot&.price&.to_d || position.current_price.to_d

      {
        symbol: position.asset.symbol,
        asset_name: position.asset.name,
        quantity: position.quantity.to_d.round(6).to_f,
        average_cost: position.average_cost.to_d.round(2).to_f,
        current_price: latest_price.round(2).to_f
      }
    end
  end

  def scoped_trades
    @scoped_trades ||= @trader.trader_trades
      .includes(:asset)
      .where(executed_at: period_range)
      .order(executed_at: :desc, created_at: :desc)
  end

  def scoped_tasks
    @scoped_tasks ||= @trader.allocation_tasks
      .where(run_on: @period_start..@period_end)
      .order(run_on: :desc, created_at: :desc)
  end

  def scoped_snapshots
    @scoped_snapshots ||= @trader.portfolio_snapshots
      .where(snapshot_date: @period_start..@period_end)
      .order(snapshot_date: :desc, captured_at: :desc)
  end

  def period_range
    @period_start.beginning_of_day..@period_end.end_of_day
  end
end
