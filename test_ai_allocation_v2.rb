#!/usr/bin/env ruby
# 测试 AiAllocationServiceV2 (独立版本，不依赖 Trader)

require_relative 'config/environment'

puts "=" * 80
puts "AiAllocationServiceV2 测试"
puts "=" * 80

# 测试参数
symbols = ["BTC", "ETH", "SOL"]
capital = 100_000
risk_preference = "balanced"

puts "[资产列表] #{symbols.join(', ')}"
puts "[可用资金] $#{capital}"
puts "[风险偏好] #{risk_preference}"
puts "-" * 80

# 创建服务实例（新的独立接口）
service = AiAllocationServiceV2.new(
  symbols: symbols,
  capital: capital,
  risk_preference: risk_preference
)

# 执行完整流程
begin
  result = service.run_full_pipeline

  puts "=" * 80
  puts "执行完成!"
  puts "=" * 80

  puts "\n[日志输出]:"
  result[:logs].each { |log| puts log }

  puts "\n[结果摘要]:"
  puts "- MCP 数据: #{result[:mcp_data]&.length || 0} 条"
  puts "- 资产数量: #{result[:assets]&.length || 0} 个"
  puts "- 信号统计: #{result[:signals].inspect}"
  puts "- 分析时间: #{result[:analyzed_at]}"

  puts "\n[AI 建议]:"
  recommendation = result[:recommendation]
  if recommendation
    puts "- 市场环境: #{recommendation[:market_condition]}"
    puts "- 风险等级: #{recommendation[:risk_level]}"
    puts "- 市场分析: #{recommendation[:market_analysis]}"
    puts "- 整体建议: #{recommendation[:overall_summary]}"

    if recommendation[:suggested_actions]&.any?
      puts "\n[操作建议]:"
      recommendation[:suggested_actions].each do |action|
        puts "  - #{action[:symbol]}: #{action[:action].upcase} (置信度: #{action[:confidence]})"
        puts "    理由: #{action[:reason]}"
      end
    end

    if recommendation[:risk_warnings]&.any?
      puts "\n[风险提示]:"
      recommendation[:risk_warnings].each { |warning| puts "  - #{warning}" }
    end
  end

rescue => e
  puts "[错误] #{e.class}: #{e.message}"
  puts e.backtrace.first(10).join("\n")
end