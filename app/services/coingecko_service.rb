# frozen_string_literal: true

# CoinGecko API 服务
# 封装 CoinGecko API 调用逻辑
#
class CoingeckoService
  BASE_URL = "https://api.coingecko.com/api/v3"
  API_KEY = ENV.fetch("COINGECKO_API_KEY", nil)

  class ApiError < StandardError; end
  class RateLimitError < StandardError; end

  # 获取市场数据（市值排名前 N 的币种）
  #
  # @param vs_currency [String] 计价货币，默认 'usd'
  # @param category [String] 分类，如 'layer-1'
  # @param order [String] 排序方式，默认 'market_cap_desc'
  # @param per_page [Integer] 每页数量，最大 250
  # @param page [Integer] 页码
  # @param price_change_percentage [String] 价格变化时间段，如 '1h,24h,7d'
  # @return [Array<Hash>] 币种市场数据数组
  #
  def fetch_markets(vs_currency: "usd", category: nil, order: "market_cap_desc",
                    per_page: 100, page: 1, price_change_percentage: "1h,24h")
    params = {
      vs_currency: vs_currency,
      order: order,
      per_page: [ per_page, 250 ].min,
      page: page,
      price_change_percentage: price_change_percentage,
      sparkline: false
    }
    params[:category] = category if category.present?

    response = get("/coins/markets", params)
    parse_json(response)
  end

  # 获取 Layer-1 币种市场数据（市值前 100）
  #
  # @return [Array<Hash>] Layer-1 币种数据
  #
  def fetch_layer1_markets
    fetch_markets(
      vs_currency: "usd",
      category: "layer-1",
      order: "market_cap_desc",
      per_page: 100,
      price_change_percentage: "1h,24h"
    )
  end

  # 获取币种历史市场数据（价格、市值、交易量）
  #
  # @param coin_id [String] CoinGecko 币种 ID（如 "bitcoin"）
  # @param vs_currency [String] 计价货币，默认 'usd'
  # @param days [Integer] 天数（1-365）
  # @return [Hash] 包含 prices, market_caps, total_volumes 数组
  #
  def fetch_market_chart(coin_id, vs_currency: "usd", days: 60)
    params = {
      vs_currency: vs_currency,
      days: days
    }

    response = get("/coins/#{coin_id}/market_chart", params)
    parse_json(response)
  end

  private

  # 发送 GET 请求
  def get(endpoint, params = {})
    uri = URI("#{BASE_URL}#{endpoint}")
    params[:x_cg_demo_api_key] = API_KEY if API_KEY.present?
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    http.open_timeout = 10

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Accept"] = "application/json"

    response = http.request(request)

    case response.code
    when "200"
      response
    when "429"
      raise RateLimitError, "CoinGecko API 速率限制，请稍后重试"
    else
      raise ApiError, "CoinGecko API 错误: #{response.code} - #{response.body[0..200]}"
    end
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise ApiError, "CoinGecko API 超时: #{e.message}"
  rescue SocketError => e
    raise ApiError, "CoinGecko API 网络错误: #{e.message}"
  end

  # 解析 JSON 响应
  def parse_json(response)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise ApiError, "CoinGecko API 响应解析失败: #{e.message}"
  end
end
