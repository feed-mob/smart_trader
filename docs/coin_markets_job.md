# CoinGecko 市场数据拉取 Job

## 功能说明

`FetchCoinMarketsJob` 是一个定时任务，用于从 CoinGecko API 拉取加密货币市场数据。

### 主要特性

- **自动拉取**: 每天 UTC 02:00 和 23:00 自动执行
- **Layer-1 聚焦**: 默认拉取 Layer-1 板块市值前 100 的币种
- **数据存储**: 同时更新 Asset 表和创建 AssetSnapshot 快照
- **幂等性**: 同一天多次执行不会创建重复快照
- **错误处理**: 完善的错误捕获和重试机制

## 配置

### 1. 环境变量

在 `.env` 文件中添加 CoinGecko API Key：

```bash
COINGECKO_API_KEY=your_coingecko_api_key
```

> 注意：CoinGecko Demo API 有速率限制（10-50 次/分钟），Pro API 限制更宽松。

### 2. 定时任务配置

定时任务已配置在 `config/sidekiq.yml` 中：

```yaml
fetch_coin_markets:
  cron: "0 2,23 * * *"
  class: "FetchCoinMarketsJob"
  queue: default
  description: "每天拉取 CoinGecko Layer-1 币种市场数据（市值前 100）"
```

可以根据需要调整执行时间。

## 使用方法

### 手动执行

```ruby
# 在 Rails console 中执行
rails c

# 拉取 Layer-1 币种（默认前 100）
FetchCoinMarketsJob.perform_later

# 拉取其他分类（如 DeFi）
FetchCoinMarketsJob.perform_later(category: "decentralized-finance-defi", per_page: 50)

# 同步执行（立即获取结果）
result = FetchCoinMarketsJob.perform_now(category: "layer-1", per_page: 100)
puts result[:stats]
```

### 查看执行结果

```ruby
# 查看 Job 执行日志
# 位置: log/sidekiq.log

# 查询最近拉取的资产
Asset.where(exchange: "COINGECKO").order(last_updated: :desc).limit(10)

# 查询某个资产的快照历史
asset = Asset.find_by(symbol: "BTC", exchange: "COINGECKO")
asset.asset_snapshots.order(snapshot_date: :desc).limit(30)
```

## 数据结构

### Asset 表

存储资产基本信息：

- `symbol`: 币种代码（如 BTC, ETH）
- `name`: 币种名称（如 Bitcoin）
- `coingecko_id`: CoinGecko ID（如 bitcoin）
- `current_price`: 当前价格
- `last_updated`: 最后更新时间

### AssetSnapshot 表

存储每日快照：

- `asset_id`: 关联资产 ID
- `snapshot_date`: 快照日期（用于唯一性约束）
- `captured_at`: 实际采集时间
- `price`: 当日价格
- `change_percent`: 24小时涨跌幅
- `volume`: 24小时交易量

## API 接口

`FetchCoinMarketsJob` 调用 CoinGecko 的 `/coins/markets` 接口：

```
GET https://api.coingecko.com/api/v3/coins/markets
  ?vs_currency=usd
  &category=layer-1
  &order=market_cap_desc
  &per_page=100
  &price_change_percentage=1h,24h
```

### 可用分类（category 参数）

- `layer-1` - Layer-1 区块链（默认）
- `decentralized-finance-defi` - DeFi 项目
- `stablecoins` - 稳定币
- `meme-token` - Meme 币
- 更多分类请参考 CoinGecko API 文档

### 历史数据 API

历史数据拉取使用 CoinGecko 的 `/coins/{id}/market_chart` 接口：

```
GET https://api.coingecko.com/api/v3/coins/{id}/market_chart
  ?vs_currency=usd
  &days=60
```

返回数据结构：
```json
{
  "prices": [[timestamp_ms, price], ...],
  "market_caps": [[timestamp_ms, market_cap], ...],
  "total_volumes": [[timestamp_ms, volume], ...]
}
```

Rake Task 会聚合每天的价格和成交量数据，保存到 asset_snapshots 表。

## 错误处理

Job 包含完善的错误处理机制：

1. **API 速率限制**: 自动等待 5 分钟后重试（最多 3 次）
2. **网络错误**: 自动等待 1 分钟后重试（最多 3 次）
3. **数据验证**: 跳过数据不完整的币种，记录错误日志
4. **唯一性约束**: 同一天不会创建重复快照

## 历史数据拉取

### 使用 Rake Task

拉取前 10 个加密货币最近 60 天的历史数据：

```bash
rails assets:fetch_historical
```

**功能说明：**
- 自动获取 assets 表中前 10 个活跃的加密货币
- 拉取每个币种最近 60 天的价格和成交量数据
- 按日期聚合并保存到 asset_snapshots 表
- 自动计算涨跌幅（基于前一天价格）
- 智能处理 API 速率限制

**执行流程：**
1. 查询前 10 个活跃的加密货币资产
2. 逐个调用 CoinGecko market_chart API
3. 聚合每天的价格和成交量数据（取当天最后一个数据点）
4. 创建或更新 AssetSnapshot 记录（包含价格、成交量、涨跌幅）
5. 自动计算涨跌幅（需要前一天的数据）

**注意事项：**
- 需要先执行 `FetchCoinMarketsJob` 创建资产记录
- CoinGecko API 有速率限制，每个请求后会暂停 1.5 秒
- 如果遇到速率限制会自动暂停 60 秒后重试
- 同一天的数据会覆盖（幂等性）

## 监控建议

### 1. 日志监控

```bash
# 监控 Job 执行日志
tail -f log/sidekiq.log | grep FetchCoinMarketsJob

# 查看今天的执行结果
grep "FetchCoinMarketsJob.*执行完成" log/sidekiq.log | tail -1
```

### 2. 数据验证

```ruby
# 检查今天是否拉取成功
today = Date.current
snapshot_count = AssetSnapshot.where(snapshot_date: today).count
puts "今天已拉取 #{snapshot_count} 个资产快照"

# 检查是否有遗漏的资产
Asset.where(exchange: "COINGECKO", active: true).left_joins(:asset_snapshots)
     .where(asset_snapshots: { snapshot_date: today })
     .count
```

### 3. Sidekiq Web UI

访问 `/sidekiq` 查看：
- 定时任务列表
- 执行历史
- 失败任务
- 队列状态

## 常见问题

### Q: 如何修改拉取时间？

A: 编辑 `config/sidekiq.yml`，修改 `cron` 表达式：

```yaml
fetch_coin_markets:
  cron: "0 2,23 * * *"  # 每天 UTC 02:00 和 23:00
  # cron: "0 */6 * * *"  # 每 6 小时
  # cron: "30 1 * * *"  # 每天凌晨 1:30
```

### Q: CoinGecko API Key 从哪里获取？

A: 访问 https://www.coingecko.com/en/api/pricing 注册账号获取 API Key。

### Q: 如何拉取更多币种？

A: 修改 Job 参数：

```ruby
FetchCoinMarketsJob.perform_later(per_page: 250)  # CoinGecko 最大支持 250
```

### Q: 如何拉取非 Layer-1 币种？

A: 修改 `category` 参数：

```ruby
FetchCoinMarketsJob.perform_later(category: "decentralized-finance-defi")
```

## 技术实现

### 核心类

- `FetchCoinMarketsJob`: Job 执行类（`app/jobs/fetch_coin_markets_job.rb`）
- `CoingeckoService`: API 封装服务（`app/services/coingecko_service.rb`）
- `Asset`: 资产模型（`app/models/asset.rb`）
- `AssetSnapshot`: 快照模型（`app/models/asset_snapshot.rb`）

### 执行流程

1. 调用 CoinGecko API 获取市场数据
2. 遍历每个币种：
   - 创建或更新 Asset 记录
   - 创建或更新当天的 AssetSnapshot 记录
3. 记录统计信息（创建/更新/错误数量）

## 扩展建议

### 1. 添加更多数据源

创建类似的 Job 拉取其他交易所数据：

- `FetchBinanceMarketsJob` - 币安数据
- `FetchYahooFinanceJob` - Yahoo Finance 股票数据

### 2. 增加告警机制

当拉取失败或数据异常时发送通知：

```ruby
if result[:stats][:errors] > 10
  # 发送 Slack/Email 通知
end
```

### 3. 数据分析

基于快照数据进行技术分析：

```ruby
# 计算 7 日均价
asset.asset_snapshots.recent(7).average(:price)

# 计算波动率
snapshots = asset.asset_snapshots.recent(30)
volatility = snapshots.stddev_pop(:change_percent)
```
