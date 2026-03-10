# frozen_string_literal: true

# AI配置建议服务 - 使用 SwarmSDK Tool 调用方式生成资产配置建议
#
# 设计理念：
# - AI Agent 通过调用 Tools 动态获取需要的数据
# - 不再一次性传递所有数据，而是让 AI 自己决定需要哪些数据
# - 支持 Context-Aware Tools (如 TraderInfoTool 需要 trader_id)
#
class AiAllocationService
  def initialize(trader)
    @trader = trader
    @capital = trader.current_capital_value
  end

  # 生成 AI 配置建议（Tool 调用方式）
  def generate_recommendation
    call_swarm_for_recommendation
  end

  private

  # 使用 SwarmSDK 多 Agent 系统生成配置建议
  def call_swarm_for_recommendation
    swarm = build_allocation_swarm
    result = swarm.execute(build_prompt)
    Rails.logger.info "[AiAllocationService] Swarm result: #{result.inspect}"
    parse_swarm_result(result)
  end

  # 构建 prompt
  def build_prompt
    <<~PROMPT
      请为操盘手生成资产配置建议。

      操盘手 ID: #{@trader.id}
      操盘手名称: #{@trader.name}
      可用资金: $#{number_with_delimiter(@capital.round(0))}

      请按以下步骤操作：
      1. 首先调用 TraderInfo(trader_id: #{@trader.id}) 获取操盘手的策略配置
      2. 使用 ListAssets 查看可用资产
      3. 使用 GetSignalData(min_confidence: 0.5) 获取高置信度的买入信号
      4. 使用 GetFactorData 获取相关资产的因子数据，判断市场环境
      5. 根据策略约束和市场环境，生成配置建议

      市场环境判断标准：
      - normal: 因子值正常，波动适中
      - volatile: 波动率因子偏高
      - crash: 多数因子为负，市场恐慌
      - bubble: 动量过热，情绪因子极端

      配置约束：
      - 遵循 max_positions 限制
      - 单资产不超过 max_position_size
      - 保留至少 min_cash_reserve 的现金
      - 只对置信度超过 buy_signal_threshold 的资产买入
    PROMPT
  end

  # 构建 Allocation Swarm - 单 Agent + Tools
  def build_allocation_swarm
    SwarmSDK.build do
      name "Asset Allocation Advisor"
      lead :coordinator

      # 协调器 Agent - 通过 Tools 获取数据并决策
      agent :coordinator do
        model "gpt-5.2"
        description "投资组合协调器，通过调用 Tools 获取数据并生成配置建议"

        system_prompt <<~PROMPT
          你是 SmartTrader 的投资组合协调器。你的职责是：

          1. 使用 TraderInfo 工具获取操盘手的策略配置
          2. 使用 ListAssets 工具查看可用资产列表
          3. 使用 GetSignalData 工具获取交易信号（建议筛选高置信度信号）
          4. 使用 GetFactorData 工具获取因子数据，判断市场环境
          5. 根据策略和市场生成配置建议

          ## 市场环境判断标准

          根据 factor 数据判断：
          - normal: 因子值正常，波动适中
          - volatile: 波动率因子偏高（percentile > 70）
          - crash: 多数因子为负，市场恐慌
          - bubble: 动量过热，情绪因子极端

          ## 配置约束

          根据策略参数：
          - max_positions: 最大持仓数量
          - max_position_size: 单资产最大仓位比例
          - min_cash_reserve: 最小现金保留比例
          - buy_signal_threshold: 买入信号最低置信度

          ## 输出格式要求

          你的最终回复必须只包含一个 JSON 对象：

          {
            "market_analysis": "市场环境分析（1-2句话）",
            "selected_strategy": "normal 或 volatile 或 crash 或 bubble",
            "strategy_selection_reason": "选择该策略的理由",
            "summary": "配置建议摘要（1-2句话）",
            "allocations": [
              {
                "symbol": "资产代码如BTC",
                "action": "buy 或 sell 或 hold",
                "allocation_percent": 30,
                "amount_usd": 30000,
                "shares": 0.5,
                "reason": "配置理由"
              }
            ],
            "cash_reserve": {
              "percent": 20,
              "amount_usd": 20000
            },
            "detailed_reasoning": "详细解释（3-5句话）"
          }

          注意：
          - 如果没有合适的买入机会，allocations 为空数组 []
          - allocation_percent + cash_reserve.percent = 100
        PROMPT

        tools :TraderInfo, :ListAssets, :GetFactorData, :GetSignalData, :GetAssetPrice
      end
    end
  end

  # 解析 Swarm 结果
  def parse_swarm_result(result)
    parse_json_response(result.content)
  end

  # 解析响应 - 使用 AiChatService 提取 JSON
  def parse_json_response(response)
    return nil if response.blank?

    Rails.logger.info "[AiAllocationService] Raw response length: #{response.length}"
    parse_markdown_response(response)
  end

  # 解析 Markdown 格式的响应 - 使用 AiChatService
  def parse_markdown_response(markdown_content)
    Rails.logger.info "[AiAllocationService] Using AiChatService to parse Markdown"

    prompt = <<~PROMPT
      请从以下资产配置建议的 Markdown 文本中提取结构化信息，返回纯 JSON 格式（不要包含 ```json 标记）。

      ## 输入文本
      #{markdown_content}

      ## 可用资金
      #{@capital}

      ## 输出要求
      返回纯 JSON 对象，不要包含 markdown 代码块标记，不要包含任何 error 相关字段。JSON 结构如下：

      {
        "market_analysis": "市场环境分析（1-2句话）",
        "selected_strategy": "normal 或 volatile 或 crash 或 bubble",
        "strategy_selection_reason": "选择该策略的理由",
        "summary": "配置建议摘要（1-2句话）",
        "allocations": [
          {
            "symbol": "资产代码如BTC",
            "action": "buy 或 sell 或 hold",
            "allocation_percent": 30,
            "amount_usd": 30000,
            "shares": 0.5,
            "reason": "配置理由"
          }
        ],
        "cash_reserve": {
          "percent": 20,
          "amount_usd": 20000
        },
        "detailed_reasoning": "详细解释（3-5句话）"
      }

      重要提示：
      - 只提取有效的配置建议数据，忽略输入文本中的任何 error 或错误信息
      - 如果没有配置任何资产（全部现金），allocations 为空数组 []
      - allocation_percent + cash_reserve.percent 必须等于 100
      - 如果文本中提到"100%现金"或"全部现金观望"，则 allocations 为空，cash_reserve.percent 为 100
      - amount_usd 需要根据可用资金和百分比计算
    PROMPT

    ai_service = AiChatService.new
    content = ai_service.ask(prompt)
    Rails.logger.info "[AiAllocationService] AiChatService response length: #{content.length}"
    Rails.logger.info "[AiAllocationService] AiChatService response content: #{content}"

    # 提取并解析 JSON
    json_string = extract_json_from_llm_response(content)
    result = JSON.parse(json_string)
    Rails.logger.info "[AiAllocationService] Successfully parsed LLM JSON with keys: #{result.keys.join(', ')}"

    symbolize_keys(result)
  rescue JSON::ParserError => e
    Rails.logger.error "[AiAllocationService] JSON parse error: #{e.message}"
    { error: "Failed to parse response", raw_response: markdown_content }
  end

  # 从 LLM 响应中提取 JSON 字符串
  def extract_json_from_llm_response(content)
    # 尝试从 markdown 代码块中提取
    if content =~ /```(?:json)?\s*(\{.*\})\s*```/m
      return Regexp.last_match(1)
    end

    # 找到 JSON 对象
    start_index = content.index("{")
    end_index = content.rindex("}")
    if start_index && end_index && end_index > start_index
      return content[start_index..end_index]
    end

    content.strip
  end

  # 将哈希的键名符号化（递归）
  def symbolize_keys(obj)
    case obj
    when Hash
      obj.transform_keys(&:to_sym).transform_values { |v| symbolize_keys(v) }
    when Array
      obj.map { |v| symbolize_keys(v) }
    else
      obj
    end
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\\1,").reverse
  end
end
