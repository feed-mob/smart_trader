# frozen_string_literal: true

class PortfolioDashboardsController < ApplicationController
  before_action :require_user

  def show
    @traders = Trader
      .includes(:trading_strategies, :allocation_tasks, :portfolio_snapshots, trader_positions: :asset, trader_trades: :asset)
      .ordered_by_created

    @trader_dashboard_rows = build_trader_dashboard_rows(@traders)
    @dashboard_stats = build_dashboard_stats(@trader_dashboard_rows)
    @portfolio_chart = build_portfolio_chart(@traders)
  end

  private

  def build_trader_dashboard_rows(traders)
    traders.map do |trader|
      latest_task = trader.allocation_tasks.max_by { |task| [task.run_on, task.created_at] }
      latest_snapshot = trader.portfolio_snapshots.max_by { |snapshot| [snapshot.snapshot_date, snapshot.captured_at] }
      active_positions = trader.trader_positions.select(&:active?)
      recent_trade = trader.trader_trades.max_by(&:executed_at)
      invested_value = active_positions.sum do |position|
        latest_price = position.asset.latest_snapshot&.price&.to_d || position.current_price.to_d
        position.quantity.to_d * latest_price
      end.round(2)
      cash_value, equity_value, profit_loss, profit_loss_percent =
        metrics_from_snapshot_or_market_value(trader, latest_snapshot, invested_value, latest_task)
      trader_chart = build_trader_chart(trader)

      {
        trader: trader,
        latest_task: latest_task,
        latest_snapshot: latest_snapshot,
        active_positions: active_positions,
        recent_trade: recent_trade,
        cash_value: cash_value.round(2),
        invested_value: invested_value,
        equity_value: equity_value,
        profit_loss: profit_loss,
        profit_loss_percent: profit_loss_percent,
        chart: trader_chart
      }
    end
  end

  def metrics_from_snapshot_or_market_value(trader, latest_snapshot, invested_value, latest_task)
    if latest_snapshot.present?
      return [
        latest_snapshot.cash_value.to_d,
        latest_snapshot.portfolio_value.to_d,
        latest_snapshot.profit_loss.to_d,
        latest_snapshot.profit_loss_percent.to_d
      ]
    end

    ending_cash = latest_task&.ending_cash.to_d
    cash_value = if latest_task.present?
                   ending_cash
                 else
                   [trader.current_capital_value.to_d - invested_value, 0.to_d].max
                 end
    equity_value = (cash_value + invested_value).round(2)
    profit_loss = (equity_value - trader.initial_capital.to_d).round(2)
    profit_loss_percent = if trader.initial_capital.to_d.positive?
                            ((profit_loss / trader.initial_capital.to_d) * 100).round(2)
                          else
                            0
                          end

    [cash_value, equity_value, profit_loss, profit_loss_percent]
  end

  def build_dashboard_stats(rows)
    active_traders = rows.count { |row| row[:trader].active? }
    total_equity = rows.sum { |row| row[:equity_value] }
    total_profit_loss = rows.sum { |row| row[:profit_loss] }
    total_positions = rows.sum { |row| row[:active_positions].size }
    completed_tasks = rows.sum { |row| row[:trader].allocation_tasks.count(&:completed?) }

    average_return = if rows.any?
                       rows.sum { |row| row[:profit_loss_percent] } / rows.size
                     else
                       0
                     end

    {
      active_traders: active_traders.size,
      total_equity: total_equity,
      total_profit_loss: total_profit_loss,
      total_positions: total_positions,
      completed_tasks: completed_tasks,
      average_return: average_return.round(2)
    }
  end

  def build_portfolio_chart(traders)
    snapshot_dates = traders.flat_map { |trader| trader.portfolio_snapshots.map(&:snapshot_date) }.compact.uniq.sort
    return empty_chart if snapshot_dates.empty?

    baseline_value = traders.sum { |trader| trader.initial_capital.to_d }
    per_trader_daily_values = traders.index_with do |trader|
      trader.portfolio_snapshots
        .group_by(&:snapshot_date)
        .transform_values { |snapshots| snapshots.max_by(&:captured_at).portfolio_value.to_d }
    end

    series = snapshot_dates.map do |date|
      total_value = traders.sum do |trader|
        latest_value_for_date(per_trader_daily_values[trader], date) || trader.initial_capital.to_d
      end

      {
        date: date,
        equity_value: total_value.round(2),
        pnl_value: (total_value - baseline_value).round(2)
      }
    end

    equity_points = chart_points(series.map { |point| point[:equity_value] })
    pnl_points = chart_points(series.map { |point| point[:pnl_value] })

    {
      baseline_value: baseline_value.round(2),
      latest_value: series.last[:equity_value],
      latest_pnl: series.last[:pnl_value],
      start_date: series.first[:date],
      end_date: series.last[:date],
      equity_path: svg_path_for(equity_points),
      pnl_path: svg_path_for(pnl_points),
      labels: build_chart_labels(series),
      has_multiple_points: series.size > 1
    }
  end

  def latest_value_for_date(daily_values, date)
    eligible_date = daily_values.keys.select { |run_on| run_on <= date }.max
    eligible_date.present? ? daily_values[eligible_date] : nil
  end

  def chart_points(values, width: 100, height: 100)
    return [] if values.empty?
    return [[0, height / 2.0]] if values.size == 1

    min_value = values.min
    max_value = values.max
    range = max_value - min_value
    range = 1 if range.zero?

    values.each_with_index.map do |value, index|
      x = (index.to_f / (values.size - 1)) * width
      normalized = (value - min_value) / range
      y = height - (normalized * height)
      [x.round(2), y.round(2)]
    end
  end

  def svg_path_for(points)
    return "" if points.empty?

    segments = points.map.with_index do |(x, y), index|
      command = index.zero? ? "M" : "L"
      "#{command} #{x} #{y}"
    end

    segments.join(" ")
  end

  def build_chart_labels(series)
    if series.size == 1
      [
        { text: series.first[:date].strftime("%m-%d"), position: "start" }
      ]
    else
      [
        { text: series.first[:date].strftime("%m-%d"), position: "start" },
        { text: series[series.size / 2][:date].strftime("%m-%d"), position: "center" },
        { text: series.last[:date].strftime("%m-%d"), position: "end" }
      ]
    end
  end

  def empty_chart
    {
      baseline_value: 0,
      latest_value: 0,
      latest_pnl: 0,
      start_date: nil,
      end_date: nil,
      equity_path: "",
      pnl_path: "",
      labels: [],
      has_multiple_points: false
    }
  end

  def build_trader_chart(trader)
    daily_values = trader.portfolio_snapshots
      .group_by(&:snapshot_date)
      .transform_values { |snapshots| snapshots.max_by(&:captured_at).portfolio_value.to_d }

    return empty_trader_chart(trader) if daily_values.empty?

    series = daily_values.keys.sort.map do |date|
      portfolio_value = daily_values[date]

      {
        date: date,
        equity_value: portfolio_value.round(2),
        pnl_value: (portfolio_value - trader.initial_capital.to_d).round(2)
      }
    end

    points = chart_points(series.map { |point| point[:equity_value] }, height: 64)

    {
      path: svg_path_for(points),
      latest_value: series.last[:equity_value],
      latest_pnl: series.last[:pnl_value],
      start_label: series.first[:date].strftime("%m-%d"),
      end_label: series.last[:date].strftime("%m-%d"),
      has_points: true
    }
  end

  def empty_trader_chart(trader)
    {
      path: "",
      latest_value: trader.current_capital_value.to_d.round(2),
      latest_pnl: (trader.current_capital_value.to_d - trader.initial_capital.to_d).round(2),
      start_label: nil,
      end_label: nil,
      has_points: false
    }
  end
end
