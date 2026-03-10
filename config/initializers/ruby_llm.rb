RubyLLM.configure do |config|
  config.openai_use_system_role = true
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY")
  config.openai_api_base = ENV.fetch("OPENAI_API_BASE")
  config.default_model = 'gpt-5.2'
end
