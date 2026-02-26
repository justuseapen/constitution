class FeedbackTriageJob < ApplicationJob
  queue_as :default

  def perform(feedback_item_id)
    feedback = FeedbackItem.find(feedback_item_id)
    return if feedback.category != "uncategorized"

    response = OPENROUTER_CLIENT.chat(
      parameters: {
        model: "anthropic/claude-haiku-4-5-20251001",
        messages: [
          { role: "system", content: "Categorize this feedback. Respond with JSON: {\"category\": \"bug|feature_request|performance\", \"score\": 1-10}" },
          { role: "user", content: "Title: #{feedback.title}\nBody: #{feedback.body}\nContext: #{feedback.technical_context.to_json}" }
        ]
      }
    )

    content = response.dig("choices", 0, "message", "content")
    parsed = JSON.parse(content) rescue {}

    feedback.update!(
      category: parsed["category"] || "uncategorized",
      score: parsed["score"],
      status: :triaged
    )
  end
end
