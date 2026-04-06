# AI Analysis 异步执行方案

## 功能说明

AI Analysis 模块提供 Web 界面调用 Claude Code CLI，用户提交 prompt 后由后台 Job 异步执行，前端通过轮询获取结果。

## 架构总览

```
用户提交表单
    │
    ▼
AiAnalysisController#create
    │  创建 record (status: pending)
    │  ExecuteAiAnalysisJob.perform_later(record.id)
    │  redirect_to show 页面
    ▼
Show 页面 (Stimulus polling)
    │  每 3s GET /ai_analysis/:id/status
    │  finished? → window.location.reload()
    ▼
ExecuteAiAnalysisJob (Sidekiq worker)
    │  record.update!(status: running, started_at: now)
    │  ClaudeCodeService#ask_with_files(prompt, files, permission_mode)
    │  record.update!(output/error, status: completed/failed, finished_at: now)
    ▼
Show 页面 reload → 显示最终结果
```

## 状态流转

```
pending → running → completed
                  → failed
```

| 状态 | 说明 | 触发时机 |
|------|------|----------|
| `pending` | 等待执行 | Controller create 时设置 |
| `running` | 正在执行 | Job 开始时更新 |
| `completed` | 执行成功 | Job 拿到成功结果 |
| `failed` | 执行失败 | Job 拿到失败结果或异常 |

## 关键文件

| 文件 | 职责 |
|------|------|
| `app/jobs/execute_ai_analysis_job.rb` | 后台 Job，调用 ClaudeCodeService 并更新记录 |
| `app/controllers/ai_analysis_controller.rb` | 控制器：create 创建记录+派发 Job，status 返回 JSON |
| `app/models/ai_analysis_record.rb` | 数据模型，状态常量和查询方法 |
| `app/services/claude_code_service.rb` | Claude Code CLI 封装 |
| `app/views/ai_analysis/show.html.erb` | 结果页面，根据状态渲染不同 UI |
| `app/javascript/controllers/ai_analysis_polling_controller.js` | Stimulus controller，轮询状态 |
| `app/assets/stylesheets/ai_analysis.css` | 样式（含 processing spinner） |
| `config/routes.rb` | 路由：`status` member action |

## Model

```ruby
# app/models/ai_analysis_record.rb
class AiAnalysisRecord < ApplicationRecord
  belongs_to :user

  STATUS_PENDING   = "pending"
  STATUS_RUNNING   = "running"
  STATUS_COMPLETED = "completed"
  STATUS_FAILED    = "failed"

  # 查询方法
  def pending?   # status == "pending"
  def running?   # status == "running"
  def success?   # status == "completed"
  def failed?    # status == "failed"
  def finished?  # completed 或 failed
end
```

### 数据库字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `user_id` | bigint | 关联用户 |
| `prompt` | text | 用户输入的指令 |
| `files` | text | 附带文件路径（换行/逗号分隔） |
| `permission_mode` | string | Claude Code 权限模式 |
| `output` | text | CLI 标准输出 |
| `error` | text | CLI 错误输出 |
| `status` | string | pending / running / completed / failed |
| `started_at` | datetime | Job 开始执行时间 |
| `finished_at` | datetime | Job 执行完成时间 |

## Job

```ruby
# app/jobs/execute_ai_analysis_job.rb
class ExecuteAiAnalysisJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 2

  def perform(record_id)
    record = AiAnalysisRecord.find(record_id)
    record.update!(status: STATUS_RUNNING, started_at: Time.current)

    service = ClaudeCodeService.new
    result = service.ask_with_files(prompt, files:, permission_mode:)

    record.update!(
      output: result[:output],
      error: result[:error],
      status: result[:success] ? STATUS_COMPLETED : STATUS_FAILED,
      finished_at: Time.current
    )
  end
end
```

- 队列：`default`（Sidekiq）
- 重试：指数退避，最多 2 次
- 继承 `ApplicationJob`，自动通过 `around_perform :track_execution` 记录 `JobExecution`

## Controller

### create

```ruby
def create
  record = current_user.ai_analysis_records.create!(
    prompt: @prompt,
    files: @files_input,
    permission_mode: @permission_mode,
    status: AiAnalysisRecord::STATUS_PENDING
  )
  ExecuteAiAnalysisJob.perform_later(record.id)
  redirect_to ai_analysis_path(id: record.id)
end
```

不再同步调用 `ClaudeCodeService`，立即 redirect 到 show 页面。

### status

```ruby
def status
  record = current_user.ai_analysis_records.find(params[:id])
  render json: {
    status: record.status,
    finished: record.finished?,
    output: record.output,
    error: record.error
  }
end
```

供前端轮询的 JSON 接口。

## 前端轮询

Stimulus controller，仅在 record 处于 `pending` 或 `running` 状态时挂载：

```javascript
// app/javascript/controllers/ai_analysis_polling_controller.js
export default class extends Controller {
  static values = { statusUrl: String, interval: { type: Number, default: 3000 } }

  connect() {
    this.pollInterval = setInterval(() => this.poll(), this.intervalValue)
  }

  poll() {
    fetch(this.statusUrlValue)
      .then(r => r.json())
      .then(data => { if (data.finished) window.location.reload() })
  }
}
```

Show 视图中的挂载方式：

```erb
<div class="neural-result"
     <% if is_processing %>
       data-controller="ai-analysis-polling"
       data-ai-analysis-polling-status-url-value="<%= status_ai_analysis_path(@record.id) %>"
     <% end %>>
```

## 路由

```ruby
# config/routes.rb
resources :ai_analysis, only: [:index, :new, :create, :show], controller: 'ai_analysis' do
  get :status, on: :member
end
```

生成的路由：

| Method | Path | Action |
|--------|------|--------|
| GET | `/ai_analysis` | index |
| GET | `/ai_analysis/new` | new |
| POST | `/ai_analysis` | create |
| GET | `/ai_analysis/:id` | show |
| GET | `/ai_analysis/:id/status` | status |
