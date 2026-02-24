# frozen_string_literal: true

class AiChatService
  MODEL = "claude-sonnet-4-6"
  PROVIDER = :openai

  def initialize(instructions: nil, temperature: 0.3, max_tokens: 1000)
    @instructions = instructions
    @temperature = temperature
    @max_tokens = max_tokens
  end

  def ask(prompt)
    chat = RubyLLM.chat(
      model: MODEL,
      provider: PROVIDER,
      assume_model_exists: true
    )

    chat.with_instructions(@instructions) if @instructions.present?
    chat.ask(prompt).content
  end
end
