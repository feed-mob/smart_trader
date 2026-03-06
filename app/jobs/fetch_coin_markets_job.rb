# frozen_string_literal: true

# 加密货币市场数据拉取 Job
# 每天拉取 CoinGecko Layer-1 币种市场数据（市值前 100）
#
# 使用方式：
#   FetchCoinMarketsJob.perform_later
#   FetchCoinMarketsJob.perform_later(category: "layer-1", per_page: 50)
#
# 定时任务配置（config/recurring.yml）：
#   fetch_coin_markets:
#     command: FetchCoinMarketsJob.perform_later
#     cron: "0 2 * * *"  # 每天凌晨 2 点执行
#
class FetchCoinMarketsJob < ApplicationJob
  queue_as :default

  # 重试配置
  retry_on CoingeckoService::RateLimitError, wait: 5.minutes, attempts: 3
  retry_on CoingeckoService::ApiError, wait: 1.minute, attempts: 3

  def perform(category: "layer-1", per_page: 50)
    @category = category
    @per_page = per_page
    @logs = []
    @stats = { created: 0, updated: 0, snapshots: 0, errors: 0 }

    log "=" * 60
    log "[FetchCoinMarketsJob] 开始执行市场数据拉取"
    log "[参数] category=#{category}, per_page=#{per_page}"
    log "=" * 60

    # 1. 获取市场数据
    markets_data = fetch_markets_data

    if markets_data.empty?
      log "[警告] 未获取到任何市场数据"
      return { success: false, message: "未获取到市场数据", stats: @stats }
    end

    # 2. 保存到数据库
    process_markets_data(markets_data)

    log "=" * 60
    log "[FetchCoinMarketsJob] 执行完成"
    log "[统计] 资产创建=#{@stats[:created]}, 更新=#{@stats[:updated]}, 快照=#{@stats[:snapshots]}, 错误=#{@stats[:errors]}"
    log "=" * 60

    { success: true, stats: @stats, logs: @logs }
  end

  private

  # 获取市场数据
  def fetch_markets_data
    log "[Phase 1] 从 CoinGecko API 获取市场数据..."

    service = CoingeckoService.new
    data = service.fetch_markets(
      vs_currency: "usd",
      category: @category,
      order: "market_cap_desc",
      per_page: @per_page,
      price_change_percentage: "1h,24h"
    )

    log "[Phase 1] 成功获取 #{data.length} 个币种数据"
    data
  rescue CoingeckoService::ApiError => e
    log "[错误] API 请求失败: #{e.message}"
    []
  end

  # 处理市场数据
  def process_markets_data(markets_data)
    log "[Phase 2] 开始处理市场数据..."

    markets_data.each_with_index do |coin_data, index|
      process_single_coin(coin_data, index + 1)
    end
  end

  # 处理单个币种数据
  def process_single_coin(coin_data, rank)
    symbol = coin_data["symbol"]&.upcase
    coingecko_id = coin_data["id"]

    unless symbol.present? && coingecko_id.present?
      log "[跳过] 数据不完整: #{coin_data.inspect[0..100]}"
      @stats[:errors] += 1
      return
    end

    ActiveRecord::Base.transaction do
      # 1. 更新或创建 Asset
      asset = upsert_asset(coin_data, symbol, coingecko_id, rank)

      # 2. 创建 AssetSnapshot（每天一个快照）
      create_daily_snapshot(asset, coin_data)
    end
  rescue => e
    log "[错误] 处理 #{symbol} 失败: #{e.message}"
    @stats[:errors] += 1
  end

  # 更新或创建资产
  def upsert_asset(coin_data, symbol, coingecko_id, rank)
    # 优先使用 coingecko_id 查找（更准确）
    asset = Asset.find_or_initialize_by(coingecko_id: coingecko_id)

    if asset.new_record?
      asset.assign_attributes(
        symbol: symbol,
        name: coin_data["name"] || symbol,
        asset_type: "crypto",
        exchange: "COINGECKO",
        quote_currency: "USD",
        active: true
      )
      @stats[:created] += 1
      log "[创建] ##{rank} #{symbol} - #{asset.name} (#{coingecko_id})"
    else
      @stats[:updated] += 1
    end

    # 更新当前价格和最后更新时间
    asset.update!(
      current_price: coin_data["current_price"],
      last_updated: Time.current
    )

    asset
  end

  # 创建每日快照
  def create_daily_snapshot(asset, coin_data)
    today = Date.current

    # 查找或初始化今天的快照
    snapshot = AssetSnapshot.find_or_initialize_by(
      asset: asset,
      snapshot_date: today
    )

    # 准备快照数据
    snapshot.assign_attributes(
      price: coin_data["current_price"] || 0,
      volume: coin_data["total_volume"] || 0,
      change_percent: coin_data["price_change_percentage_24h"] || 0,
      captured_at: parse_timestamp(coin_data["last_updated"])
    )

    if snapshot.new_record?
      snapshot.save!
      @stats[:snapshots] += 1
      log "[快照] #{asset.symbol} @ $#{snapshot.price&.round(4)} (#{snapshot.change_percent&.round(2)}%)"
    else
      # 更新今天的快照（如果已存在）
      snapshot.update!(
        price: coin_data["current_price"] || snapshot.price,
        volume: coin_data["total_volume"] || snapshot.volume,
        change_percent: coin_data["price_change_percentage_24h"] || snapshot.change_percent,
        captured_at: parse_timestamp(coin_data["last_updated"])
      )
      log "[更新] #{asset.symbol} 今日快照已更新"
    end
  end

  # 解析时间戳
  def parse_timestamp(timestamp)
    return Time.current if timestamp.blank?

    Time.parse(timestamp)
  rescue ArgumentError
    Time.current
  end

  # 日志方法
  def log(message)
    @logs << "[#{Time.current.strftime('%H:%M:%S')}] #{message}"
    Rails.logger.info "[FetchCoinMarketsJob] #{message}"
  end
end
