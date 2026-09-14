# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Lokka::OnThisDayPost do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:date) { Date.new(2026, 9, 12) }

  def finder(random: Random)
    described_class.new(date: date, cache: cache, random: random)
  end

  it 'caches candidate IDs by year and month-day' do
    cached_post = create(:post, created_at: Time.utc(2025, 9, 12))

    expect(finder.find).to eq(cached_post)
    expect(cache.read('on_this_day_post_ids/2026/0912')).to eq([cached_post.id])

    create(:post, created_at: Time.utc(2024, 9, 12))
    expect(finder.find).to eq(cached_post)
  end

  it 'uses a new cache key in a new year so the previous year becomes eligible' do
    old_post = create(:post, created_at: Time.utc(2025, 9, 12))
    expect(finder.find).to eq(old_post)

    previous_year_post = create(:post, created_at: Time.utc(2026, 9, 12))
    next_year_finder = described_class.new(
      date: Date.new(2027, 9, 12),
      cache: cache,
      random: Random
    )
    next_year_finder.find

    expect(cache.read('on_this_day_post_ids/2027/0912')).to contain_exactly(
      old_post.id,
      previous_year_post.id
    )
  end

  it 'selects an ID in Ruby and fetches only that published post' do
    first_post = create(:post, created_at: Time.utc(2024, 9, 12))
    selected_post = create(:post, created_at: Time.utc(2025, 9, 12))
    cache.write(
      'on_this_day_post_ids/2026/0912',
      [first_post.id, selected_post.id]
    )
    random = instance_double(Random)
    allow(random).to receive(:rand).with(2).and_return(1)

    result = finder(random: random).find

    expect(result).to eq(selected_post)
    described_class::ASSOCIATIONS.each do |association|
      expect(result.association(association)).to be_loaded
    end
  end

  it 'keeps the three-day window across the year boundary' do
    matching_posts = [
      create(:post, created_at: Time.utc(2011, 12, 29)),
      create(:post, created_at: Time.utc(2018, 1, 1)),
      create(:post, created_at: Time.utc(2024, 1, 4))
    ]
    create(:post, created_at: Time.utc(2020, 12, 28))

    described_class.new(
      date: Date.new(2026, 1, 1),
      cache: cache,
      random: Random
    ).find

    expect(cache.read('on_this_day_post_ids/2026/0101')).to contain_exactly(
      *matching_posts.map(&:id)
    )
  end
end
