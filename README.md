# SmartTrader (智能交易者)

## 技术栈

- **Ruby**: 4.0.1
- **Rails**: 8.1.2
- **Database**: PostgreSQL
- **CSS**: Tailwind CSS
- **JavaScript**: Turbo, Stimulus
- **Components**: ViewComponent
- **AI Integration**: Claude Code, LLM, Skills, MCP

## 快速开始

### 环境要求

- Ruby 4.0.1
- PostgreSQL
- Node.js (for asset compilation)

### 安装步骤

1. 克隆仓库
```bash
git clone git@github.com:feed-mob/smart_trader.git
cd smart_trader
```

2. 安装依赖
```bash
bundle install
```

3. 配置环境变量
```bash
cp .env.sample .env
# 编辑 .env 文件,配置数据库连接
```

4. 创建数据库
```bash
rails db:create
rails db:migrate
```

5. 初始化操盘手数据
```bash
rails init:traders
```

这将创建 6 个默认操盘手（巴菲特、芒格、林奇、索罗斯、达里奥、格雷厄姆），每个操盘手包含 4 种市场环境的交易策略。

6. 启动服务
```bash
bin/dev
```

或分开运行:
```bash
rails server
```

访问 http://localhost:3000

## 环境变量配置

参考 `.env.sample` 文件配置以下变量:

- `PRIMARY_DATABASE_URL`: PostgreSQL 数据库连接地址

## 开发工具

### 数据初始化任务

```bash
# 初始化操盘手数据（创建 6 个默认操盘手）
rails init:traders

# 初始化因子定义
bundle exec rails runner db/seeds/factor_definitions.rb

# 初始化 Mock 数据 (开发/测试环境)
bundle exec rails runner db/seeds/mock_factor_data.rb
bundle exec rails runner db/seeds/mock_trading_signals.rb
```

### 资产数据拉取

```bash
# 拉取 CoinGecko Layer-1 币种市场数据（每日）
rails c
> FetchCoinMarketsJob.perform_now

# 拉取历史市场数据（最近 60 天，前 10 个资产）
rails assets:fetch_historical
```

详细文档: [docs/coin_markets_job.md](docs/coin_markets_job.md)


## 因子系统初始化

因子系统需要初始化种子数据才能正常工作。

### 1. 初始化因子定义

```bash
bundle exec rails runner db/seeds/factor_definitions.rb
```

### 2. 初始化 Mock 数据 (开发/测试环境)

如果需要测试因子矩阵和相关性页面，可以创建模拟数据：

```bash
bundle exec rails runner db/seeds/mock_factor_data.rb
```

这将创建：
- 5 个资产 (BTC, ETH, AAPL, NVDA, GLD)
- 每个资产 30 天的价格快照
- 所有资产的因子值

### 3. 因子系统页面

初始化完成后，可以访问以下页面：

| 页面 | 路径 | 说明 |
|------|------|------|
| 因子列表 | `/admin/factor_definitions` | 管理因子配置 |
| 因子详情 | `/admin/factor_definitions/:id` | 查看因子信息和公式 |
| 因子矩阵 | `/admin/factor_definitions/matrix` | 资产 × 因子 得分热力图 |
| 因子相关性 | `/admin/factor_definitions/correlations` | 因子间相关性分析 |

### 4. 生产环境

生产环境不应该使用 mock 数据，应该：
1. 运行因子定义 seed
2. 配置数据采集任务 (CollectAssetDataJob)
3. 配置因子计算任务 (CalculateFactorsJob)

## 信号系统

信号系统基于因子数据，通过 AI 生成交易信号。

### 1. 初始化 Mock 信号数据 (开发/测试环境)

```bash
bundle exec rails runner db/seeds/mock_trading_signals.rb
```

这将创建：
- 每个资产的最新交易信号
- 部分资产的历史信号记录

### 2. 信号系统页面

| 页面 | 路径 | 说明 |
|------|------|------|
| 信号列表 | `/admin/trading_signals` | 查看所有交易信号 |
| 信号详情 | `/admin/trading_signals/:id` | 查看信号详情和因子快照 |

### 3. 信号生成

- **手动生成**: 在信号列表页面点击"生成全部信号"
- **自动生成**: 配置 GenerateSignalsJob 定时任务

### 4. 信号类型

| 类型 | 说明 |
|------|------|
| Buy (买入) | AI 判断建议买入 |
| Sell (卖出) | AI 判断建议卖出 |
| Hold (持有) | AI 判断建议持有观望 |

每个信号包含：
- 置信度 (0-100%)
- 推理说明
- 关键驱动因子
- 风险提示
- 因子快照


