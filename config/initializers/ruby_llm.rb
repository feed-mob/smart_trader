RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("ANTHROPIC_API_KEY")
  config.openai_api_base = ENV.fetch("ANTHROPIC_API_BASE")
end
