RubyLLM.configure do |config|
  config.openai_use_system_role = true
  config.openai_api_key = ENV["OPENAI_API_KEY"] if ENV["OPENAI_API_KEY"].present?
  config.openai_api_base = ENV["OPENAI_API_BASE"] if ENV["OPENAI_API_BASE"].present?
  config.default_model = 'gpt-5.2'
end
