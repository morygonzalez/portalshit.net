require 'openai'

class EntrySummarizer
  MODEL = 'gpt-4o'

  def initialize(content)
    @content = content
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  def summarize
    response = @client.chat(
      parameters: {
        model: MODEL,
        messages: [
          { role: "system", content: "以下のブログ記事を著者になりきって、日本語で簡潔に要約してください。ただし、結論は要約に含めないようにしてください。文章の長さは100文字以内で、受動態表現と「ですます」調を避けて下さい。" },
          { role: "user", content: @content }
        ],
        temperature: 0.3,
        max_tokens: 150
      }
    )
    response.dig("choices", 0, "message", "content").strip
  rescue => e
    puts "要約生成エラー: #{e.message}"
    nil
  end
end
