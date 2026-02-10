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

5. 启动服务
```bash
rails server
```

访问 http://localhost:3000

## 环境变量配置

参考 `.env.sample` 文件配置以下变量:

- `PRIMARY_DATABASE_URL`: PostgreSQL 数据库连接地址

## 开发工具

项目集成了以下开发工具:

- `pry-byebug`: 调试工具
- `pry-rails`: Rails 控制台增强
- `rubocop-rails-omakase`: 代码风格检查
- `brakeman`: 安全漏洞扫描
- `bundler-audit`: 依赖安全审计
