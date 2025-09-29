require 'openai'

class EntryTagGenerator
  MODEL = 'gpt-5-mini'
  PROMPT = <<~EOF
添付のブログ記事に関して、文章の内容を反映したタグを付与してください。ただし、以下の条件を遵守してください。

1. ブログ全体のタグの一覧は「 %s 」です。ふさわしいものがあればそこから利用してください。なければ新しいタグを考えて設定してください。
2. タグの数は最大で 5 個までとします。
3. すでにタグが付与されている場合は、現在のタグを加味して 5 個までタグを付与してください。現在のタグが内容にふさわしくなければ削除しても構いません。
4. タグは極力一語で構成されるようにしてください。固有名詞の場合はその限りではありません。
5. 略語は避けてください。固有名詞の場合はその限りではありません。
6. 「減量ダイエット」のような意味が重複する二つの単語で構成されるタグは付与しないでください。固有名詞の場合はその限りではありません。
7. タグは半角スペースを含んでも問題ありません。"GoogleAnalytics" ではなく "Google Analytics" でよいです。
8. レスポンスは JSON フォーマットで、以下のような形式にしてください。

```json
{
  "tags": ["tag1", "tag2"...]
}
```

# ブログ記事 #

## タイトル ##

%s

## 本文

%s

## すでに付与済みのタグ

%s
EOF

  attr_reader :response

  def initialize(title, body, tags)
    @title = title
    @body = body
    @tags = tags
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  def generate
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
                    puts "タグ生成エラー: #{e.message}"
                    nil
                  end
  end

  def input
    PROMPT % [Tag.joins(:entries).pluck(:name), @title, @body, @tags]
  end
end
