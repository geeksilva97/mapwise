RubyLLM.configure do |config|
  config.anthropic_api_key = Rails.application.credentials.dig(:anthropic_api_key)
  config.openai_api_key    = Rails.application.credentials.dig(:openai_api_key)
  config.gemini_api_key    = Rails.application.credentials.dig(:gemini_api_key)
end
