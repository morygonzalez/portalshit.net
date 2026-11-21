module OpenAIResponseText
  def self.extract(response)
    response.fetch('output', []).each do |item|
      next unless item['type'] == 'message' && item['role'] == 'assistant'

      content = item.fetch('content', []).find { |part| part['type'] == 'output_text' }
      return content.fetch('text') if content
    end

    raise 'OpenAI response does not contain assistant output text'
  end
end
