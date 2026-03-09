# frozen_string_literal: true

namespace :coins do
  desc "Fetch historical market data for top 50 coins that don't have yesterday's data"
  task fetch_historical: :environment do
    include CoinsHistoricalDataHelper

    puts "=" * 80
    puts "开始拉取 Coin 历史市场数据 (市值前 50)"
    puts "=" * 80

    # 确保基准资产存在
    ensure_benchmark_assets

    # 获取昨天没有数据的资产
    yesterday = Date.yesterday

    # 所有活跃的加密货币资产（只取市值前 50）
    all_crypto_assets = Asset.active.crypto
      .where.not(coingecko_id: nil)
      .where.not(market_cap_rank: nil)
      .where("market_cap_rank <= 50")

    # 筛选出昨天没有快照的资产
    assets_with_yesterday_data = AssetSnapshot
      .where(snapshot_date: yesterday)
      .joins(:asset)
      .where(assets: { asset_type: 'crypto', active: true })
      .where.not(assets: { coingecko_id: nil })
      .distinct
      .pluck('assets.id')

    assets = all_crypto_assets.where.not(id: assets_with_yesterday_data)

    if assets.empty?
      puts "✅ 所有资产都已有昨天的数据，无需拉取"
      exit 0
    end

    puts "\n找到 #{assets.count} 个资产缺少昨天的数据:"
    assets.each_with_index do |asset, index|
      puts "  #{index + 1}. #{asset.symbol} - #{asset.name} (#{asset.coingecko_id})"
    end
    puts "\n"

    service = CoingeckoService.new
    stats = { success: 0, failed: 0, total_snapshots: 0 }

    assets.each_with_index do |asset, index|
      puts "\n[#{index + 1}/#{assets.count}] 处理 #{asset.symbol}..."

      begin
        # 拉取最近 5 天的数据
        data = service.fetch_market_chart(asset.coingecko_id, days: 5)

        if data["prices"].blank?
          puts "  ⚠️  没有获取到价格数据"
          stats[:failed] += 1
          next
        end

        # 聚合并保存快照（包括价格和成交量）
        snapshot_count = save_price_snapshots(asset, data["prices"], data["total_volumes"])

        puts "  ✅ 成功保存 #{snapshot_count} 条快照"
        stats[:success] += 1
        stats[:total_snapshots] += snapshot_count

        # 避免 API 速率限制，每个请求后暂停
        sleep(1.5) unless index == assets.count - 1

      rescue CoingeckoService::RateLimitError => e
        puts "  ⛔ 遇到速率限制，暂停 60 秒..."
        sleep(60)
        retry
      rescue => e
        puts "  ❌ 失败: #{e.message}"
        stats[:failed] += 1
      end
    end

    puts "\n" + "=" * 80
    puts "Coin 历史数据拉取完成"
    puts "  ✅ 成功: #{stats[:success]}"
    puts "  ❌ 失败: #{stats[:failed]}"
    puts "  📊 总快照数: #{stats[:total_snapshots]}"
    puts "=" * 80
  end
end

module CoinsHistoricalDataHelper
  # 确保基准资产存在
  def ensure_benchmark_assets
    benchmark_assets = [
      {
        symbol: 'XAUT',
        name: 'Tether Gold',
        asset_type: 'crypto',
        exchange: 'COINGECKO',
        quote_currency: 'USD',
        coingecko_id: 'tether-gold',
        market_cap_rank: 0,
        active: true
      }
    ]

    benchmark_assets.each do |attrs|
      asset = Asset.find_or_initialize_by(symbol: attrs[:symbol], exchange: attrs[:exchange])
      if asset.new_record?
        asset.assign_attributes(attrs)
        asset.save!
        puts "✓ 创建基准资产: #{asset.name} (#{asset.symbol})"
      end
    end
  end

  # 聚合并保存价格和成交量快照
  #
  # @param asset [Asset] 资产对象
  # @param prices [Array<Array>] 价格数据 [[timestamp_ms, price], ...]
  # @param volumes [Array<Array>] 成交量数据 [[timestamp_ms, volume], ...]
  # @return [Integer] 保存的快照数量
  #
  def save_price_snapshots(asset, prices, volumes = [])
    # 按日期聚合数据（一天取最后一个数据点）
    daily_prices = aggregate_data_by_date(prices)
    daily_volumes = aggregate_data_by_date(volumes)

    saved_count = 0

    daily_prices.each do |date, price_data|
      begin
        # 使用 find_or_create_by 避免重复创建
        snapshot = AssetSnapshot.find_or_initialize_by(
          asset: asset,
          snapshot_date: date
        )

        # 获取对应的成交量数据
        volume_data = daily_volumes[date]

        # 更新快照数据
        snapshot.assign_attributes(
          price: price_data[:value],
          volume: volume_data&.dig(:value) || 0,
          captured_at: price_data[:captured_at],
          change_percent: calculate_change_percent(asset, date, price_data[:value])
        )

        snapshot.save!
        saved_count += 1
      rescue => e
        puts "    ⚠️  保存 #{date} 快照失败: #{e.message}"
      end
    end

    saved_count
  end

  # 按日期聚合数据（价格或成交量）
  #
  # @param data_points [Array<Array>] 原始数据 [[timestamp_ms, value], ...]
  # @return [Hash<Date, Hash>] { date => { value:, captured_at: } }
  #
  def aggregate_data_by_date(data_points)
    daily_data = {}

    data_points.each do |timestamp_ms, value|
      # 将毫秒时间戳转换为 Time 和 Date
      time = Time.at(timestamp_ms / 1000.0)
      date = time.to_date

      # 保留每天最后一个数据点（覆盖之前的）
      daily_data[date] = {
        value: value,
        captured_at: time
      }
    end

    daily_data
  end

  # 计算涨跌幅
  #
  # @param asset [Asset] 资产对象
  # @param date [Date] 当前日期
  # @param current_price [Float] 当前价格
  # @return [Float, nil] 涨跌幅百分比
  #
  def calculate_change_percent(asset, date, current_price)
    # 查找前一天的快照
    previous_snapshot = AssetSnapshot.find_by(
      asset: asset,
      snapshot_date: date - 1.day
    )

    return nil unless previous_snapshot&.price&.positive?

    ((current_price - previous_snapshot.price) / previous_snapshot.price * 100).round(4)
  end
end
