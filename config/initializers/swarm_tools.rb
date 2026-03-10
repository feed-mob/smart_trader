# frozen_string_literal: true

# SwarmSDK Tools 初始化
# 在 Rails 启动时自动加载并注册所有自定义 Tools

Rails.application.config.after_initialize do
  # 确保 SwarmSDK 已加载
  next unless defined?(SwarmSDK)

  # 加载所有 Tool 文件
  Dir[Rails.root.join("app", "tools", "*_tool.rb")].sort.each do |file|
    require_dependency file
  end

  [
    ListAssetsTool,
    GetAssetPriceTool,
    GetFactorDataTool,
    GetSignalDataTool,
    TraderInfoTool,
    CalculateFactorsTool,
    GenerateSignalsTool
  ].each do |tool_class|
    SwarmSDK.register_tool(tool_class)
    inferred_name = tool_class.name.sub(/Tool\z/, "").to_sym
    Rails.logger.info "[SwarmTools] Registered: #{tool_class.name} -> :#{inferred_name}"
  rescue StandardError => e
    Rails.logger.warn "[SwarmTools] Failed to register #{tool_class.name}: #{e.message}"
  end

  Rails.logger.info "[SwarmTools] Initialized 7 tools"
rescue StandardError => e
  Rails.logger.error "[SwarmTools] Initialization error: #{e.message}"
  Rails.logger.error e.backtrace.first(10).join("\n")
end
