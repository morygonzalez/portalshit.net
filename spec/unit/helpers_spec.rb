# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Lokka::Helpers do
  describe 'published_post_counts_by_category' do
    it 'counts published posts without applying the default ordering' do
      category = create(:category)
      create(:post, category: category)
      create(:post, category: category, draft: true)
      queries = []
      subscriber = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql] if payload[:sql].match?(/COUNT\(/i) }

      ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
        expect(published_post_counts_by_category[category.id]).to eq(1)
      end
      expect(queries).not_to be_empty
      expect(queries.join).not_to match(/ORDER BY/i)
    end
  end

  describe 'latest_posts_by_category' do
    it 'selects one latest published post per category, breaking timestamp ties by id' do
      category = create(:category)
      other_category = create(:category, title: 'Other', slug: 'other')
      time = Time.utc(2025, 1, 1)
      create(:post, category: category, created_at: time - 1.day)
      create(:post, category: category, created_at: time)
      latest = create(:post, category: category, created_at: time)
      create(:post, category: category, created_at: time + 1.day, draft: true)
      other = create(:post, category: other_category, created_at: time)

      expect(latest_posts_by_category([category, other_category])).to eq(category.id => latest, other_category.id => other)
    end
  end

  describe 'gravatar_image_url' do
    it 'should return image url' do
      gravatar_image_url('test@example.com').should eql('//www.gravatar.com/avatar/55502f40dc8b7c769880b10874abc9d0')
      gravatar_image_url.should eql('//www.gravatar.com/avatar/00000000000000000000000000000000')
    end
  end

  describe 'months' do
    subject { months }
    before  { create(:post, draft: true) }

    it { subject.count.should eq(0) }
  end
end

describe Lokka::PermalinkHelper do
  before do
    Option.permalink_enabled = true
    Option.permalink_format = '/%year%/%monthnum%/%day%/%slug%'
  end

  after do
    Option.permalink_enabled = false
  end

  describe 'custom_permalink_parse' do
    it 'custom_permalink_parse split path valid and return Hash' do
      described_class.custom_permalink_parse('/2011/01/09/welcome').should \
        eq(year: '2011', monthnum: '01', day: '09', slug: 'welcome')
    end
  end

  describe 'custom_permalink_fix' do
    it 'should return corrected URL by padding zero' do
      create(:entry, created_at: '2011-01-09T23:45:45', slug: 'welcome')
      described_class.custom_permalink_fix('/2011/1/9/welcome').should eq('/2011/01/09/welcome')
    end

    it 'should return nil for correct URL' do
      described_class.custom_permalink_fix('/2011/01/09/welcome').should be_nil
    end

    it 'should return nil when any error is raised' do
      Option.permalink_format = '/%year' # wrong format to raise error
      described_class.custom_permalink_fix('/2011').should be_nil
    end
  end

  describe 'custom_permalink_entry' do
    it 'should parse date condition' do
      entry = create(:entry, created_at: '2011-01-09T23:45:45', slug: 'slug')
      expect(described_class.custom_permalink_entry('/2011/01/09/slug').id).to eq(entry.id)
    end

    it 'should return nil when any error is raised' do
      described_class.custom_permalink_entry('/no/such/path').should be_nil
    end
  end
end
