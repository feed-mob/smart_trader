class WeatherTool < RubyLLM::Tool
  description "Get weather for a city"
  param :city, type: "string", required: true

  def execute(city:)
    # Call weather API
    "Weather in #{city}: Sunny, 72°F"
  end
end