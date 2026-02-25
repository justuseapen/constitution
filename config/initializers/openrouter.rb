OPENROUTER_CLIENT = OpenAI::Client.new(
  access_token: ENV.fetch("OPENROUTER_API_KEY", ""),
  uri_base: "https://openrouter.ai/api/v1"
)
