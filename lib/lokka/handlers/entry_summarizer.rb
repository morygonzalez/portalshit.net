require 'openai'

class EntrySummarizer
  MODEL = 'gpt-5-mini'
  PROMPT = <<~EOF
添付のブログ記事に関して、ブログ記事の著者本人になりきって、日本語で簡潔に要約してください。ただし、以下の条件を遵守してください。

1. 結論は要約に含めないようにしてください。
2. 文章の長さは150文字（語数ではなく文字数）以内にしてください。
3. 受動態表現と「ですます」調を避けて下さい。
4. レスポンスは JSON フォーマットで、以下のような形式にしてください。

```json
{
  "summary": "summary..."
}
```

# ブログ記事 #

## タイトル ##

%s

## 本文 ##

%s
EOF

  attr_reader :response

  def initialize(title, body)
    @title = title
    @body = body
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  def summarize
    @response ||= begin
                    request = @client.responses.create(
                      parameters: {
                        model: MODEL,
                        input: input,
                        reasoning: { effort: 'minimal' }
                      }
                    )
                    JSON.parse(request.dig("output", 1, "content", 0, "text").strip)
                  rescue => e
                    puts "要約生成エラー: #{e.message}"
                    nil
                  end
  end

  def input
    PROMPT % [@title, @body]
  end
end
