# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Category cards' do
  it 'shows the latest published post and published post count for each category' do
    create(:site, theme: 'portalshit')
    category = create(:category, description: 'Category description example')
    create(:post, category: category, title: 'Older category post', created_at: Time.utc(2024, 1, 1))
    latest = create(:post, category: category, title: 'Latest category post', created_at: Time.utc(2025, 2, 3, 12, 34))
    create(:post, category: category, title: 'Draft category post', created_at: Time.utc(2026, 1, 1), draft: true)

    get '/categories'

    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Category description example', 'Latest category post', latest.reload.created_at.iso8601, "#{I18n.t('theme.entry_count')} 2")
    expect(last_response.body).not_to include('Older category post', 'Draft category post')
  end

  it 'renders category cards on a missing page' do
    create(:site, theme: 'portalshit')
    category = create(:category, description: 'Another category description')
    create(:post, category: category, title: 'Category post')

    get '/missing-page-for-category-cards'

    expect(last_response.status).to eq(404)
    expect(last_response.body).to include('Another category description', 'Category post', "#{I18n.t('theme.entry_count')} 1")
  end
end
