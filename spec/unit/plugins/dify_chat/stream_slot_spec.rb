# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lokka::DifyChat do
  # SSE は応答完了まで Puma のスレッドを 1 本占有するため、同時ストリーム数を
  # プロセス内で数えて上限を超えたら弾く。カウンタはモジュールの状態なので
  # 各テストの前後で必ず 0 に戻す。
  around do |example|
    described_class.instance_variable_set(:@stream_count, 0)
    example.run
    described_class.instance_variable_set(:@stream_count, 0)
  end

  describe '.acquire_stream_slot' do
    it 'grants slots up to the configured maximum' do
      acquired = Array.new(described_class::MAX_CONCURRENT_STREAMS) { described_class.acquire_stream_slot }

      expect(acquired).to all(be true)
    end

    it 'refuses the slot once the maximum is reached' do
      described_class::MAX_CONCURRENT_STREAMS.times { described_class.acquire_stream_slot }

      expect(described_class.acquire_stream_slot).to be false
    end

    it 'grants a slot again after one is released' do
      described_class::MAX_CONCURRENT_STREAMS.times { described_class.acquire_stream_slot }
      described_class.release_stream_slot

      expect(described_class.acquire_stream_slot).to be true
    end
  end

  describe '.release_stream_slot' do
    it 'never lets the counter go negative' do
      3.times { described_class.release_stream_slot }

      expect(described_class.instance_variable_get(:@stream_count)).to eq 0
    end
  end

  # 取得はルートブロック、解放は stream ブロックの ensure と別のタイミングで
  # 走るので、並行に呼ばれても上限を超えないことを固定しておく。
  it 'does not hand out more slots than the maximum under concurrent access' do
    results = Queue.new
    threads = Array.new(described_class::MAX_CONCURRENT_STREAMS * 4) do
      Thread.new { results << described_class.acquire_stream_slot }
    end
    threads.each(&:join)

    granted = Array.new(results.size) { results.pop }.count(true)
    expect(granted).to eq described_class::MAX_CONCURRENT_STREAMS
  end
end
