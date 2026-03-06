# Coolify 部署指南

本文档介绍如何将 SmartTrader 项目部署到 Coolify 平台。

## 目录

- [前置要求](#前置要求)
- [项目准备](#项目准备)
- [Coolify 配置](#coolify-配置)
- [环境变量](#环境变量)
- [部署步骤](#部署步骤)
- [常见问题](#常见问题)

## 前置要求

1. 一台已安装 Coolify 的服务器（或使用 Coolify Cloud）
2. GitHub/GitLab 仓库访问权限
3. 域名（可选，但推荐）

## 项目准备

### 1. 确保 Dockerfile 存在

项目根目录需要有 `Dockerfile`。如果使用 Kamal 部署，应该已经有 `Dockerfile`。

### 2. 数据库配置

确保 `config/database.yml` 支持环境变量配置：

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  host: <%= ENV.fetch("DATABASE_HOST") { "localhost" } %>
  port: <%= ENV.fetch("DATABASE_PORT") { 5432 } %>
  username: <%= ENV.fetch("DATABASE_USERNAME") { "postgres" } %>
  password: <%= ENV.fetch("DATABASE_PASSWORD") { "" } %>

production:
  <<: *default
  database: <%= ENV.fetch("DATABASE_NAME") { "smart_trader_production" } %>
```

### 3. 添加 dockerignore（如不存在）

创建 `.dockerignore` 文件：

```
.git
.gitignore
README.md
.env*
!.env.example
node_modules
log/*
tmp/*
storage/*
public/assets
.bundle
vendor/bundle
```

## Coolify 配置

### 方式一：通过 Git 仓库部署（推荐）

1. **登录 Coolify 控制台**

   访问你的 Coolify 实例（通常是 `https://coolify.yourdomain.com`）

2. **创建新项目**

   - 点击 "New Project"
   - 输入项目名称：`SmartTrader`

3. **添加新服务**

   - 在项目中选择 "New Resource" → "Service"
   - 选择 "Git Repository"

4. **配置 Git 仓库**

   - Repository URL: `https://github.com/your-org/smart_trader`
   - Branch: `main`
   - Build Pack: `Nixpacks` 或 `Docker`

5. **配置构建设置**

   如果使用 Nixpacks：
   - Build Command: `bundle install && rails assets:precompile`
   - Start Command: `bin/rails server -b 0.0.0.0 -p ${PORT:-3000}`

   如果使用 Docker：
   - Dockerfile Location: `/Dockerfile`
   - 确保 Dockerfile 暴露正确的端口

### 方式二：通过 Docker Compose 部署

1. 创建 `docker-compose.coolify.yml`：

```yaml
version: '3.8'

services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - RAILS_ENV=production
      - DATABASE_HOST=db
      - DATABASE_USERNAME=postgres
      - DATABASE_PASSWORD=${DATABASE_PASSWORD}
      - DATABASE_NAME=smart_trader_production
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
    depends_on:
      - db
      - redis
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${DATABASE_PASSWORD}
      - POSTGRES_DB=smart_trader_production
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

2. 在 Coolify 中选择 "Docker Compose" 部署方式

## 环境变量

在 Coolify 的 "Environment Variables" 部分添加以下变量：

### 必需变量

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `RAILS_ENV` | Rails 环境 | `production` |
| `SECRET_KEY_BASE` | Rails 密钥 | `rails secret` 生成 |
| `DATABASE_HOST` | 数据库主机 | `db` 或 Postgres 服务地址 |
| `DATABASE_USERNAME` | 数据库用户名 | `postgres` |
| `DATABASE_PASSWORD` | 数据库密码 | 强密码 |
| `DATABASE_NAME` | 数据库名称 | `smart_trader_production` |
| `ANTHROPIC_API_KEY` | Claude API 密钥 | `sk-ant-...` |

### 可选变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `RAILS_MAX_THREADS` | 最大线程数 | `5` |
| `WEB_CONCURRENCY` | Web 并发数 | `2` |
| `PORT` | 应用端口 | `3000` |

### 生成 SECRET_KEY_BASE

```bash
rails secret
# 或
openssl rand -hex 64
```

## 部署步骤

### 1. 添加数据库服务

1. 在 Coolify 项目中添加 PostgreSQL 服务
2. 记录数据库连接信息
3. 更新 Web 服务的环境变量

### 2. 配置域名

1. 在服务设置中添加自定义域名
2. 配置 DNS 记录指向 Coolify 服务器
3. 启用 HTTPS（Coolify 自动配置 Let's Encrypt）

### 3. 首次部署

1. 点击 "Deploy" 按钮开始部署
2. 查看构建日志确认无错误
3. 部署成功后访问应用

### 4. 数据库迁移

首次部署后需要运行数据库迁移：

**方法 A：通过 Coolify Terminal**

1. 进入 Coolify 控制台
2. 点击服务的 "Terminal"
3. 运行：
```bash
rails db:migrate
```

**方法 B：修改启动命令**

在 Dockerfile 或启动命令中添加：

```dockerfile
# 在 CMD 之前添加
RUN echo '#!/bin/bash\nset -e\nrails db:prepare\nexec bin/rails server -b 0.0.0.0 -p ${PORT:-3000}' > /rails/start.sh && chmod +x /rails/start.sh
CMD ["/rails/start.sh"]
```

**方法 C：添加 release 步骤（推荐）**

在 `bin/rails` 中添加或创建 `config/initializers/db_prepare.rb`：

```ruby
# config/initializers/db_prepare.rb
if Rails.env.production?
  begin
    ActiveRecord::Migration.maintain_test_schema!
  rescue ActiveRecord::PendingMigrationError => e
    Rails.logger.info "Running pending migrations..."
    system("rails db:migrate")
  end
end
```

更好的方式是在 `config/deploy.yml`（如果使用 Kamal）或通过启动脚本处理：

```bash
#!/bin/bash
set -e

# 等待数据库就绪
until nc -z $DATABASE_HOST 5432; do
  echo "Waiting for database..."
  sleep 1
done

# 运行迁移
rails db:migrate

# 启动服务
exec bin/rails server -b 0.0.0.0 -p ${PORT:-3000}
```

## 配置自动部署

### GitHub Actions 集成

1. 在 Coolify 中获取 Webhook URL：
   - 进入服务设置
   - 找到 "Webhooks"
   - 复制 Deploy Hook URL

2. 在 GitHub 仓库添加 Secrets：
   - `COOLIFY_WEBHOOK`: Webhook URL

3. 创建 `.github/workflows/deploy.yml`：

```yaml
name: Deploy to Coolify

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Coolify Deploy
        run: curl -X POST ${{ secrets.COOLIFY_WEBHOOK }}
```

## 健康检查

在 Coolify 中配置健康检查：

- **Health Check Path**: `/health`
- **Health Check Interval**: 30s
- **Health Check Timeout**: 10s

添加健康检查路由：

```ruby
# config/routes.rb
get "/health", to: proc { [200, {}, ["OK"]] }
```

## 常见问题

### 1. 数据库连接失败

**问题**: 应用无法连接到数据库

**解决方案**:
- 确认数据库服务已启动
- 检查 `DATABASE_HOST` 是否正确（Docker 网络中使用服务名）
- 确认数据库用户名密码正确

### 2. 资源预编译失败

**问题**: CSS/JS 资产编译失败

**解决方案**:
```bash
# 确保安装了 Node.js
# 在 Dockerfile 中添加：
RUN apt-get update && apt-get install -y nodejs npm
```

### 3. 首次部署后 500 错误

**问题**: 部署成功但访问返回 500

**解决方案**:
- 检查日志：`docker logs <container_id>`
- 确认 `SECRET_KEY_BASE` 已设置
- 确认数据库迁移已运行

### 4. SSL 证书问题

**问题**: HTTPS 无法访问

**解决方案**:
- 确认 DNS 已正确指向 Coolify 服务器
- 等待 Let's Encrypt 证书生成（可能需要几分钟）
- 检查 Coolify 的 SSL 设置

### 5. 环境变量未生效

**问题**: 环境变量设置后应用未读取

**解决方案**:
- 重新部署应用
- 确认变量名拼写正确
- 检查是否有 `.env` 文件覆盖

## 监控与日志

### 查看日志

1. 在 Coolify 控制台选择服务
2. 点击 "Logs" 标签
3. 实时查看应用日志

### 资源监控

Coolify 提供内置的资源监控：
- CPU 使用率
- 内存使用
- 网络流量
- 磁盘使用

## 扩展阅读

- [Coolify 官方文档](https://coolify.io/docs)
- [Rails 部署指南](https://guides.rubyonrails.org/deployment.html)
- [Docker 最佳实践](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

## 更新部署

```bash
# 本地更新代码后推送到 Git
git push origin main

# Coolify 会自动触发部署（如果配置了 Webhook）
# 或手动在 Coolify 控制台点击 "Redeploy"
```

## 回滚

在 Coolify 控制台：
1. 进入服务详情
2. 点击 "Deployments" 标签
3. 选择之前的成功部署
4. 点击 "Rollback"
