# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Portalshit comment replies' do
  include_context 'in site'

  let(:entry) { create(:post) }

  before do
    allow_any_instance_of(Lokka::App).to receive(:render_detect_with_options) do |app|
      app.haml :'theme/portalshit/entry', layout: false
    end
    allow_any_instance_of(Lokka::App).to receive(:partial).and_return('')
  end

  it 'displays approved public replies beneath their parent comment' do
    parent = create(:comment, entry: entry, body: 'Parent comment')
    reply = create(:comment, entry: entry, parent: parent, body: 'Reply comment')
    get entry.link
    document = Nokogiri::HTML(last_response.body)
    parent_node = document.at_css("#comment-#{parent.id}")
    expect(parent_node.text).to include('Parent comment', 'Reply comment')
    expect(parent_node.at_css(".comment-replies #comment-#{reply.id}")).to be_present
  end

  it 'does not display private replies on the public entry' do
    parent = create(:comment, entry: entry, private: true, body: 'Private parent')
    create(:comment, entry: entry, parent: parent, private: true, status: Comment::MODERATED, body: 'Private reply')
    get entry.link
    expect(last_response.body).not_to include('Private parent', 'Private reply')
  end
end
