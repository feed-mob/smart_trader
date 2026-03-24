# Trader 反思报告方案

本文档描述 SmartTrader 中 `Trader Reflection Report` 的设计与最小可行版本实现方案。

## 目标

为每个 trader 增加一层“交易反思”能力。

系统基于以下数据：

- 当前策略参数
- 最近一段时间的交易记录
- allocation decision / task 执行结果
- 组合净值快照
- 当前持仓与浮盈亏

通过 LLM 输出一份结构化反思报告，用来回答：

- 最近做得好的地方是什么
- 最近做错的地方是什么
- 哪些行为模式值得警惕
- 是否建议微调策略
- 如果要微调，优先动哪些参数

## 为什么先做“报告”，不直接自动改策略

第一版不应直接让 LLM 自动修改策略。

原因：

- 短期盈亏噪声很大，直接自动调参容易过拟合
- 需要先验证 LLM 反思输出是否稳定、可解释
- 需要为后续“策略微调”保留人工确认和变更记录

因此 MVP 只做：

- 生成反思报告
- 展示反思报告
- 提供结构化的建议调整项

不做：

- 自动写回 `trading_strategies`
- 自动替换 strategy description
- 自动改变风险等级

## MVP 范围

第一版反思报告仅覆盖：

1. trader 当前策略上下文
2. 最近 30 天交易流水
3. 最近 30 天 allocation task 执行结果
4. 最近组合净值与累计盈亏
5. 当前持仓浮盈亏

输出内容包括：

- 总结摘要
- 做得好的地方
- 主要问题
- 行为模式观察
- 风险提示
- 建议调整项
- 是否建议继续当前策略

## 数据来源

反思报告主要依赖现有表：

- `trading_strategies`
- `trader_trades`
- `allocation_decisions`
- `allocation_tasks`
- `portfolio_snapshots`
- `trader_positions`

不需要修改交易执行引擎，也不需要先做 realized P&L 精确核算引擎。

## 建议新增模型

建议新增：

### `trader_reflections`

字段建议：

- `trader_id`
- `trading_strategy_id`
- `reflection_period_start`
- `reflection_period_end`
- `status`
- `source`
- `metrics`
- `llm_summary`
- `findings`
- `suggested_adjustments`
- `prompt_version`
- `generated_at`
- `error_message`

说明：

- `metrics` 保存结构化统计输入摘要
- `findings` 保存 strengths / mistakes / patterns / risk_issues
- `suggested_adjustments` 保存参数建议
- `status` 至少支持 `pending / generated / failed`

## LLM 输出格式

第一版不要只存自由文本，建议要求 LLM 返回 JSON。

建议结构：

```json
{
  "summary": "对最近交易表现的简短总结",
  "strengths": ["做得好的地方 1", "做得好的地方 2"],
  "mistakes": ["主要问题 1", "主要问题 2"],
  "pattern_findings": ["观察到的行为模式 1"],
  "risk_issues": ["风险点 1"],
  "suggested_adjustments": [
    {
      "parameter": "buy_signal_threshold",
      "direction": "increase",
      "reason": "最近买入门槛偏低，导致追高"
    }
  ],
  "recommendation": "是否建议维持当前策略或进行微调"
}
```

## 策略调整边界

反思报告里允许建议，但不自动应用。

建议允许被提及的参数仅限：

- `max_positions`
- `buy_signal_threshold`
- `max_position_size`
- `min_cash_reserve`

暂不允许：

- 修改 trader 描述
- 自动改风险等级
- 自动生成全新策略文本

## 页面入口

MVP 建议直接挂在 trader 详情页：

- 增加“生成反思报告”按钮
- 展示最近一份反思报告
- 可列出最近几份历史报告

这样用户可以围绕某个 trader 看完整闭环：

- 当前策略
- 当前持仓
- 最近交易
- 最近执行
- 最新反思

## 服务设计

建议新增：

### `TraderReflectionService`

职责：

- 收集 trader 过去一段时间的交易和快照
- 计算基础统计指标
- 组织 LLM prompt
- 解析结构化 JSON
- 写入 `TraderReflection`

服务输出：

- 一条 `TraderReflection` 记录

### 可选后续扩展

后续可新增：

- `GenerateTraderReflectionJob`
- `ApplyTraderStrategyAdjustmentService`

但不在第一版实现范围内。

## MVP 成功标准

第一版上线后，满足以下条件即可认为成功：

1. 用户可以在 trader 页面生成反思报告
2. 报告能够落库
3. 报告包含结构化结论，不只是原始文本
4. 报告能指出至少一类行为问题或风险提示
5. 不会自动更改 trader 策略

## 第二阶段再做什么

在反思报告稳定后，再考虑：

1. 加入“人工确认后应用调整”
2. 记录策略变更前后参数
3. 引入策略版本历史
4. 对建议值增加安全边界约束
5. 引入 realized P&L 更精确计算

## 当前实现策略

本仓库第一版将按以下路径落地：

1. 新建 `TraderReflection` 模型与表
2. 新建 `TraderReflectionService`
3. 在 `traders/:id` 页面加“生成反思报告”按钮
4. 展示最新一份报告
5. 仅做只读反思，不自动调策略
