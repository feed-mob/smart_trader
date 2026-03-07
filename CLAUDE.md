# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

SmartTrader (智能交易者) 是一个 AI 驱动的交易平台，使用 LLM 生成交易策略。核心理念是 "Everything is Agent" - AI 操盘手分析市场并做出投资决策。


表设计文档： docs/database_schema.md

## 开发命令

```bash
# 环境搭建
bundle install
cp .env.sample .env  # 配置 PRIMARY_DATABASE_URL
rails db:create db:migrate

# 启动开发服务器 (同时运行 web 和 CSS 监听)
bin/dev

# 或分开运行:
rails server

# 代码质量检查
rubocop
brakeman
bundler-audit
```

## 架构说明

### 核心领域模型

- **Trader**: AI 操盘手，包含风险等级 (conservative/balanced/aggressive)、初始资金、交易策略
- **TradingStrategy**: 每种市场环境 (normal/volatile/crash/bubble) 下的策略参数，由 LLM 生成或使用预设矩阵
- **User**: 通过 Google Sign-In 认证的用户

### 策略矩阵系统

`TradingStrategy::STRATEGY_MATRIX` 定义了 12 种预设策略 (3 种风险等级 × 4 种市场环境)。创建操盘手时：

1. 用户提供一段描述投资风格的文字
2. `StrategyGeneratorService` 调用 `AiChatService` 为 4 种市场环境分别生成策略
3. 策略存储时标记 `generated_by: :llm`，若 AI 生成失败则使用矩阵默认值

### AI 集成

- 使用 `ruby_llm` gem，模型为 Claude Sonnet 4.6
- `AiChatService` 封装 LLM 调用，支持自定义指令和温度参数
- `StrategyGeneratorService` 根据操盘手描述和市场环境生成交易参数（最大持仓数、买入阈值、仓位上限、现金保留比例）

### 关键文件

- `app/models/trading_strategy.rb` - 包含 STRATEGY_MATRIX 常量，定义 12 种预设策略
- `app/services/strategy_generator_service.rb` - 基于 LLM 的策略生成服务
- `app/services/ai_chat_service.rb` - RubyLLM 封装
- `project_document.md` - 完整功能路线图，包含 12 个规划模块

## 技术栈

- **Ruby**: 4.0.1
- **Rails**: 8.1.2
- **数据库**: PostgreSQL (`pg` gem)
- **资源管道**: Propshaft
- **CSS**: Tailwind CSS (`tailwindcss-rails`)
- **JavaScript**: Turbo + Stimulus (`turbo-rails`, `stimulus-rails`)
- **组件**: ViewComponent
- **AI**: RubyLLM (Claude Sonnet 4.6)
- **认证**: Google Sign-In (`google_sign_in`)
- **部署**: Kamal + Docker + Thruster
- **队列/缓存/Cable**: Solid Queue, Solid Cache, Solid Cable

## 认证流程

- 使用 `google_sign_in` gem 实现 Google OAuth
- 路由: `GET /login` → `POST /auth/google/callback` → `DELETE /logout`
- `SessionsController` 处理 OAuth 回调和用户创建
- 当前用户存储在 session 中

## V1 优先模块

详见 `project_document.md`。V1 阶段需实现的模块：

1. **操盘手管理** - CRUD + 基于文字描述的 LLM 档案生成
2. **资产数据采集** - 使用 MCP/Skills (yahoo-finance, ccxt) 的后台任务
3. **操盘手资产面板** - 持仓展示和图表
4. **自动资产配置** - 定时任务进行组合再平衡
5. **信号广场** - 基于多因子分析的交易信号
6. **交易因子系统** - 技术因子、基本面因子、情绪因子

## 数据库结构

```
users (google_id, email, name, avatar_url)
traders (name, description, risk_level, initial_capital, current_capital, status)
trading_strategies (trader_id, name, risk_level, market_condition, max_positions,
                    buy_signal_threshold, max_position_size, min_cash_reserve,
                    generated_by, description)
```

## 代码风格

使用 `rubocop-rails-omakase` 进行 Ruby 代码风格检查。提交前运行 `rubocop`。
