# frozen_string_literal: true

require 'spec_helper'

describe Lokka::AmazonAssociate::Fetcher do
  let(:base_dir) do
    File.join(File.dirname(__FILE__), '../../../../')
  end

  before do
    # File.stub(:read).with("#{base_dir}tmp/amazon/#{item_id}.json").
    File.stub(:read).and_return(File.read("#{base_dir}spec/fixtures/#{item_id}.json"))
  end

  describe '#get_path' do
    subject do
      described_class.new(item_id).get_path
    end

    context "item_id = '4341085239'" do
      let(:item_id) do
        '4341085239'
      end

      it 'return cache file path' do
        expect(subject).to \
          eq(File.expand_path(File.join(base_dir, 'tmp/amazon/4341085239.json')))
      end
    end
  end

  describe '#fetch' do
    before do
      Amazon::Ecs.stub(:options=).and_return(true)
      fake_option = Class.new
      %i[associate_tag access_key_id secret_key].each do |method|
        fake_option.stub(method)
      end
      stub_const('Option', fake_option)
      Amazon::Ecs.stub(:item_lookup).with(item_id, []).and_return(
        JSON.parse(
          File.read(File.expand_path(File.join(base_dir, 'spec/fixtures/4341085239.json')))
        )
      )
    end

    subject do
      described_class.new(item_id).fetch
    end

    context "item_id = '4341085239'" do
      let(:item_id) do
        '4341085239'
      end

      it 'return Hash' do
        expect(subject).to be_kind_of(Hash)
      end
    end
  end

  describe '#cache_alive?' do
    subject do
      described_class.new('4341085239').cache_alive?
    end

    context 'cache is valid' do
      before do
        File.stub(:exists?).and_return(true)
        File.stub_chain(:stat, :mtime).and_return(Time.now - 60 * 10)
      end

      it { expect(subject).to be_true }
    end

    context 'cache is expired' do
      before do
        File.stub(:exists?).and_return(true)
        File.stub_chain(:stat, :mtime).and_return(Time.now - 60 * 60 * 25)
      end

      it { expect(subject).to be_false }
    end

    context "cache file doesn't exist" do
      before do
        File.stub(:exists?).and_return(false)
        File.stub_chain(:stat, :mtime).and_return(Time.now - 60 * 10)
      end

      it { expect(subject).to be_false }
    end
  end

  describe '#wirite_or_touch_cache' do
    context 'fetch success' do
      before do
        xml = JSON.parse(
          File.read(File.expand_path(File.join(base_dir, 'spec/fixtures/4341085239.json')))
        ).to_xml
        Hash.stub(:from_xml).with(xml)
        fake_response = Class.new
        fake_response.stub_chain(:doc, :to_xml).and_return(xml)
        described_class.any_instance.stub(:fetch).and_return(fake_response)
      end

      it 'File.open が呼ばれる' do
        File.should_receive(:open)
        described_class.new('4341085239').wirite_or_touch_cache
      end
    end

    context 'fetch fail' do
      before do
        described_class.any_instance.stub(:fetch).and_return(false)
      end

      it 'FileUtils.touch が呼ばれる' do
        FileUtils.should_receive(:touch)
        described_class.new('4341085239').wirite_or_touch_cache
      end
    end
  end
end
