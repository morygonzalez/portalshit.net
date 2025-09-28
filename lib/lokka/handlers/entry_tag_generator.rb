require 'openai'

class EntryTagGenerator
  MODEL = 'gpt-5-mini'
  PROMPT = <<~EOF
以下のブログ記事に関して、次の作業をしてください。

1. この文章の内容を反映したタグを抽出してください。タグの数は最大で 5 個までとします。タグは極力一語で構成されるようにし、略語は避けてください。また「減量ダイエット」のような意味が重複する二つの単語で構成されるタグは付与しないでください。固有名詞の場合はその限りではありません。

レスポンスは JSON フォーマットで、以下のような形式にしてください。

{
  "tags": ["tag1", "tag2"...]
}

# ブログ記事本文

EOF

  attr_reader :response

  def initialize(content)
    @content = content
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
    %(#{PROMPT}#{@content})
  end
end
