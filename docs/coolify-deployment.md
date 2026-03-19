# SmartTrader Coolify 部署说明

本文档针对当前仓库 `https://github.com/feed-mob/smart_trader`，说明如何使用 Coolify 发布系统。

适用场景：

- Coolify 自托管或 Coolify Cloud
- GitHub 私有仓库
- Rails 8 + Dockerfile 部署
- PostgreSQL + Redis + Sidekiq

## 推荐部署架构

不要把所有东西硬塞进一个容器。这个项目当前依赖：

- Rails Web
- PostgreSQL
- Redis
- Sidekiq Worker

推荐在 Coolify 中创建 4 个资源：

1. `smart-trader-web`
2. `smart-trader-worker`
3. `smart-trader-postgres`
4. `smart-trader-redis`

说明：

- `web` 负责页面、API、登录、后台页面
- `worker` 负责 Sidekiq 后台任务
- `postgres` 存业务数据
- `redis` 给 Sidekiq、缓存、Action Cable 使用

## 当前仓库可直接复用的内容

这个仓库已经具备 Dockerfile 部署条件：

- 有 [Dockerfile](/Users/jason/rails/smart_trader/Dockerfile)
- 有 [bin/docker-entrypoint](/Users/jason/rails/smart_trader/bin/docker-entrypoint)
- 有 [config/puma.rb](/Users/jason/rails/smart_trader/config/puma.rb)
- 有健康检查路由 `/up`，见 [config/routes.rb](/Users/jason/rails/smart_trader/config/routes.rb)
- 生产环境启用了 `Sidekiq`，见 [config/environments/production.rb](/Users/jason/rails/smart_trader/config/environments/production.rb)

因此，Coolify 里最合适的构建方式是：

- Git 源部署
- Build Pack 选择 `Dockerfile`

不建议优先走 `Nixpacks`。

## 部署前需要注意的事项

### 1. 当前 production 数据库配置不够理想

当前 [config/database.yml](/Users/jason/rails/smart_trader/config/database.yml) 中：

- `development` 使用 `PRIMARY_DATABASE_URL`
- `production` 不是 `DATABASE_URL` 模式
- `production` 仍然是拆开的 `database / username / password` 结构

这意味着：

- 在 Coolify 中虽然可以创建 PostgreSQL
- 但 Rails production 不能很自然地直接使用 Coolify 提供的标准连接串

建议上线前把 `production` 改成支持：

```yml
production:
  url: <%= ENV.fetch("DATABASE_URL") %>
```

这是部署前最值得先改的一处。

### 2. `/sidekiq` 现在直接挂在公网路由上

当前 [config/routes.rb](/Users/jason/rails/smart_trader/config/routes.rb) 直接挂载了：

```ruby
mount Sidekiq::Web => "/sidekiq"
```

上线前建议为生产环境增加鉴权保护，否则任何知道地址的人都可以访问 Sidekiq 面板。

### 3. Google 登录需要补生产域名

当前项目使用 Google 登录，相关变量见：

- [config/initializers/google_sign_in.rb](/Users/jason/rails/smart_trader/config/initializers/google_sign_in.rb)
- [app/views/sessions/new.html.erb](/Users/jason/rails/smart_trader/app/views/sessions/new.html.erb)

上线后需要在 Google Cloud Console 中补充生产域名，否则登录可能失败。

### 4. `action_mailer.default_url_options` 仍是占位值

当前 [config/environments/production.rb](/Users/jason/rails/smart_trader/config/environments/production.rb) 中仍是：

```ruby
config.action_mailer.default_url_options = { host: "example.com" }
```

如果未来使用邮件功能，需要换成正式域名。

## 在 Coolify 中接入 GitHub 仓库

推荐方式：

- `Private Repository (with GitHub App)`

原因：

- 仓库是私有仓库
- GitHub App 权限范围更清晰
- 自动部署更顺手

Coolify 官方文档：

- GitHub App Setup: https://coolify.io/docs/applications/ci-cd/github/setup-app

### 具体步骤

1. 登录你的 Coolify：`https://coolify.tonob.net/login`
2. 进入 `Sources`
3. 添加 GitHub App
4. 给 GitHub App 授权访问仓库：
   - `feed-mob/smart_trader`
5. 创建资源时选择：
   - `Private Repository (with GitHub App)`

## Web 应用配置

创建一个应用，例如：

- 名称：`smart-trader-web`

推荐参数：

- Repository: `feed-mob/smart_trader`
- Branch: 你的发布分支，例如 `main`
- Build Pack: `Dockerfile`
- Dockerfile 路径：`/Dockerfile`
- Base Directory: `/`
- Exposed Port: `80`

原因：

- 当前 [Dockerfile](/Users/jason/rails/smart_trader/Dockerfile) 已经 `EXPOSE 80`
- 默认 `CMD` 是：

```dockerfile
CMD ["./bin/thrust", "./bin/rails", "server"]
```

因此不需要额外自定义 web 启动命令。

### Health Check

建议配置：

- Path: `/up`

对应路由定义见 [config/routes.rb](/Users/jason/rails/smart_trader/config/routes.rb)：

```ruby
get "up" => "rails/health#show", as: :rails_health_check
```

Coolify 官方文档：

- Health Checks: https://coolify.io/docs/knowledge-base/health-checks

## Worker 应用配置

再创建一个应用，例如：

- 名称：`smart-trader-worker`

它与 `web` 使用同一个仓库、同一个分支、同一个 Dockerfile。

不同点是启动命令要覆盖为：

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

说明：

- `worker` 不需要暴露域名
- `worker` 不需要走 HTTP 健康检查
- 它只负责消费 Sidekiq 队列

仓库中相关配置：

- [Procfile](/Users/jason/rails/smart_trader/Procfile)
- [config/sidekiq.yml](/Users/jason/rails/smart_trader/config/sidekiq.yml)
- [config/initializers/sidekiq.rb](/Users/jason/rails/smart_trader/config/initializers/sidekiq.rb)

## PostgreSQL 配置

在 Coolify 中创建 PostgreSQL 数据库，例如：

- 名称：`smart-trader-postgres`

创建后会得到连接信息。

推荐 Rails 最终使用：

- `DATABASE_URL`

如果你完成了前面提到的 `database.yml` 调整，那么在 Coolify 中直接给：

```env
DATABASE_URL=postgres://USER:PASSWORD@HOST:5432/DB_NAME
```

即可。

## Redis 配置

在 Coolify 中创建 Redis，例如：

- 名称：`smart-trader-redis`

创建后将连接串配置给：

```env
REDIS_URL=redis://HOST:6379/0
```

当前项目中以下地方依赖 Redis：

- Sidekiq client/server
- Rails cache
- Action Cable

见：

- [config/initializers/sidekiq.rb](/Users/jason/rails/smart_trader/config/initializers/sidekiq.rb)
- [config/environments/production.rb](/Users/jason/rails/smart_trader/config/environments/production.rb)
- [config/cable.yml](/Users/jason/rails/smart_trader/config/cable.yml)

## 生产环境变量

`web` 和 `worker` 至少都需要以下变量。

### 必需变量

```env
RAILS_ENV=production
RAILS_MASTER_KEY=your_master_key
DATABASE_URL=postgres://USER:PASSWORD@HOST:5432/DB_NAME
REDIS_URL=redis://HOST:6379/0
OAUTH_GOOGLE_CLIENT_ID=your_google_client_id
OAUTH_GOOGLE_CLIENT_SECRET=your_google_client_secret
OPENAI_API_KEY=your_openai_api_key
OPENAI_API_BASE=your_openai_api_base
```

如果生产环境会用到 CoinGecko，也补上：

```env
COINGECKO_API_KEY=your_coingecko_api_key
```

### 常用可选变量

```env
RAILS_LOG_LEVEL=info
RAILS_MAX_THREADS=3
WEB_CONCURRENCY=1
JOB_CONCURRENCY=1
```

说明：

- `RAILS_MASTER_KEY` 来自本地 [config/master.key](/Users/jason/rails/smart_trader/config/master.key)
- `OPENAI_API_BASE` 当前项目里是实际使用中的变量，不要漏掉

## 域名配置

在 Coolify 的 `web` 应用中绑定正式域名，例如：

- `trader.example.com`

然后把 DNS 指向 Coolify 所在服务器。

Coolify 官方文档：

- Domains: https://coolify.io/docs/knowledge-base/domains

## 首次部署流程

推荐顺序：

1. 先创建 PostgreSQL
2. 再创建 Redis
3. 创建 `smart-trader-web`
4. 创建 `smart-trader-worker`
5. 配置环境变量
6. 先部署 `web`
7. 再部署 `worker`

## 数据库初始化

当前 [bin/docker-entrypoint](/Users/jason/rails/smart_trader/bin/docker-entrypoint) 中：

```bash
if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
  ./bin/rails db:prepare
fi
```

因此：

- `web` 容器启动时会自动执行 `db:prepare`
- 包含建库、迁移等初始化动作

但前提是：

- 数据库连接可用
- 生产数据库权限足够

## 上线后建议立即检查

上线后建议先检查这些地址和功能：

1. `/up`
2. `/login`
3. 首页 `/`
4. `traders`
5. `portfolio_dashboard`
6. Sidekiq 任务是否真的在跑

此外要重点验证：

- Google 登录是否正常
- Redis 是否连接成功
- Sidekiq 是否开始消费任务
- 静态资源是否加载正常

## 当前项目的最小可用部署方案

如果你只想尽快上线，最小方案是：

1. 保留现有 Dockerfile
2. 在 Coolify 上创建：
   - PostgreSQL
   - Redis
   - Web App
   - Worker App
3. 配置环境变量
4. 部署

但更稳的上线前处理仍然是：

1. 把 production 数据库配置改成 `DATABASE_URL`
2. 给 `/sidekiq` 增加生产鉴权

## 不建议的方案

当前仓库不建议优先使用：

- `Nixpacks`
- 单容器同时跑 Web + Worker
- 直接把 `.env` 原样搬到生产

原因：

- 仓库已经有生产级 Dockerfile，没有必要再让 Nixpacks 猜
- Web 和 Worker 混跑不利于排障和扩缩容
- 本地 `.env` 中的值是开发环境配置，不适合直接用于生产

## Coolify 官方参考文档

- GitHub App: https://coolify.io/docs/applications/ci-cd/github/setup-app
- Applications Overview: https://coolify.io/docs/applications/
- Dockerfile Build Pack: https://coolify.io/docs/applications/build-packs/dockerfile
- Environment Variables: https://coolify.io/docs/knowledge-base/environment-variables
- Health Checks: https://coolify.io/docs/knowledge-base/health-checks
- Domains: https://coolify.io/docs/knowledge-base/domains

## 建议的下一步

如果准备正式上 Coolify，建议先做这两处代码调整：

1. 把 [config/database.yml](/Users/jason/rails/smart_trader/config/database.yml) 的 production 改成支持 `DATABASE_URL`
2. 给 [config/routes.rb](/Users/jason/rails/smart_trader/config/routes.rb) 里的 `/sidekiq` 增加生产环境访问保护

做完这两处，再上 Coolify，会顺很多。
