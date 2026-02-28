# frozen_string_literal: true

# 资产数据拉取 Job
# 使用 CoinGecko API 获取加密货币价格数据
#
# 使用方式：
#   FetchAssetsJob.perform_later(["BTC", "ETH", "SOL"])
#   FetchAssetsJob.perform_later                    # 使用默认资产列表
#
class FetchAssetsJob < ApplicationJob
  queue_as :default

  # CoinGecko API 配置
  COINGECKO_API_URL = "https://api.coingecko.com/api/v3/simple/price"
  COINGECKO_API_KEY = ENV.fetch("COINGECKO_API_KEY", "CG-cp6dbkZ4vR8xuWpPqFB7nGyB")

  # 默认监控的资产列表
  DEFAULT_SYMBOLS = %w[BTC ETH SOL BNB XRP ADA DOGE AVAX DOT MATIC].freeze

  # Symbol 到 CoinGecko ID 的映射
  SYMBOL_TO_COINGECKO_ID = {
    "BTC" => "bitcoin",
    "ETH" => "ethereum",
    "SOL" => "solana",
    "BNB" => "binancecoin",
    "XRP" => "ripple",
    "ADA" => "cardano",
    "DOGE" => "dogecoin",
    "AVAX" => "avalanche-2",
    "DOT" => "polkadot",
    "MATIC" => "matic-network",
    "LINK" => "chainlink",
    "UNI" => "uniswap",
    "ATOM" => "cosmos",
    "LTC" => "litecoin",
    "BCH" => "bitcoin-cash"
  }.freeze

  def perform(symbols = nil)
    @symbols = normalize_symbols(symbols || default_symbols)
    @logs = []

    log "=" * 60
    log "[FetchAssetsJob] 开始执行资产数据拉取"
    log "[资产列表] #{@symbols.join(', ')}"
    log "=" * 60

    # 获取资产数据
    assets_data = fetch_assets_data

    if assets_data.empty?
      log "[警告] 未获取到任何资产数据"
      return { success: false, message: "未获取到资产数据" }
    end

    # 保存到数据库
    saved_count = save_assets_to_database(assets_data)

    log "=" * 60
    log "[FetchAssetsJob] 执行完成，成功保存 #{saved_count} 个资产"
    log "=" * 60

    { success: true, saved_count: saved_count, logs: @logs }
  end

  private

  # 规范化资产代码
  def normalize_symbols(symbols)
    symbols.map do |symbol|
      symbol.to_s.upcase.gsub(/[^A-Z]/, "")
    end.reject(&:empty?).uniq
  end

  # 获取默认资产列表
  def default_symbols
    # 优先从数据库获取用户关注的资产
    watched_symbols = Asset.all.pluck(:symbol).map { |s| s.gsub(/USDT$/, "") }
    watched_symbols.any? ? watched_symbols : DEFAULT_SYMBOLS
  end

  # 获取资产数据
  def fetch_assets_data
    log "[Phase 1] 使用 CoinGecko API 获取资产数据..."

    data = fetch_from_coingecko

    log "[Phase 1] 成功获取 #{data.length} 条资产数据"
    data
  end

  # 从 CoinGecko API 获取数据
  def fetch_from_coingecko
    # 将 symbols 转换为 CoinGecko IDs
    coingecko_ids = @symbols.map { |s| SYMBOL_TO_COINGECKO_ID[s] }.compact

    if coingecko_ids.empty?
      log "[错误] 无法映射任何 symbol 到 CoinGecko ID"
      return []
    end

    log "[CoinGecko] 请求 IDs: #{coingecko_ids.join(', ')}"

    # 构建 API 请求 URL
    uri = URI(COINGECKO_API_URL)
    params = {
      ids: coingecko_ids.join(","),
      vs_currencies: "usd",
      include_24hr_vol: "true",
      include_24hr_change: "true",
      include_last_updated_at: "true",
      x_cg_demo_api_key: COINGECKO_API_KEY
    }
    uri.query = URI.encode_www_form(params)

    log "[CoinGecko] 请求 URL: #{uri.to_s[0..100]}..."

    begin
      # 发送 HTTP 请求
      response = Net::HTTP.get_response(uri)

      if response.code != "200"
        log "[错误] CoinGecko API 返回错误: #{response.code} - #{response.body[0..200]}"
        return []
      end

      # 解析 JSON 响应
      json_data = JSON.parse(response.body)
      log "[CoinGecko] 收到 #{json_data.keys.length} 个资产数据"

      # 转换为标准格式
      parse_coingecko_response(json_data)
    rescue => e
      log "[错误] CoinGecko API 请求失败: #{e.message}"
      []
    end
  end

  # 解析 CoinGecko API 响应
  def parse_coingecko_response(json_data)
    data = []

    # 反向映射：CoinGecko ID -> Symbol
    id_to_symbol = SYMBOL_TO_COINGECKO_ID.invert

    json_data.each do |coingecko_id, asset_data|
      symbol = id_to_symbol[coingecko_id]
      next unless symbol

      usd_data = asset_data["usd"] || {}

      data << {
        symbol: "#{symbol}USDT",
        price: usd_data&.dig("usd") || 0.0,
        change_percent: usd_data&.dig("usd_24h_change")&.round(4) || 0.0,
        volume_24h: usd_data&.dig("usd_24h_vol")&.to_i || 0,
        market_cap: usd_data&.dig("usd_market_cap"),
        last_updated_at: usd_data&.dig("last_updated_at") ? Time.at(usd_data["last_updated_at"]) : Time.current,
        exchange: "COINGECKO",
        source: "coingecko_api"
      }

      log "[解析] #{symbol}: $#{data.last[:price].round(4)} (#{data.last[:change_percent]}%)"
    end

    data
  end

  # 保存资产数据到数据库
  def save_assets_to_database(assets_data)
    log "[Phase 2] 开始保存资产数据到数据库..."
    saved_count = 0

    assets_data.each do |data|
      begin
        # 查找或创建 Asset
        asset = Asset.find_or_initialize_by(symbol: data[:symbol])

        if asset.new_record?
          asset.name = data[:symbol].gsub("USDT", "")
          asset.asset_type = "crypto"
          asset.save!
          log "[DB] 创建新资产: #{asset.symbol} (ID: #{asset.id})"
        end

        # 创建 AssetSnapshot
        snapshot = asset.asset_snapshots.create!(
          price: data[:price],
          volume: data[:volume_24h],
          change_percent: data[:change_percent],
          captured_at: data[:last_updated_at] || Time.current,
          metadata: {
            exchange: data[:exchange],
            source: data[:source],
            market_cap: data[:market_cap]
          }
        )

        log "[DB] 快照: #{asset.symbol} @ $#{snapshot.price.round(4)} (#{snapshot.change_percent}%)"
        saved_count += 1
      rescue => e
        log "[错误] 保存 #{data[:symbol]} 失败: #{e.message}"
      end
    end

    log "[Phase 2] 成功保存 #{saved_count} 条资产快照"
    saved_count
  end

  # 日志方法
  def log(message)
    @logs << "[#{Time.current.strftime('%H:%M:%S')}] #{message}"
    Rails.logger.info "[FetchAssetsJob] #{message}"
  end
end