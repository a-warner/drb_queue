require 'spec_helper'

describe DrbQueue do
  it { should_not be_nil }

  def connect_to_redis!
    Redis.current = Redis::Namespace.new(described_class.to_s, :redis => Redis.new(:db => 8))
  end

  before(:all) do
    DrbQueue.configure do |c|
      c.after_fork do
        connect_to_redis!
      end
    end
  end

  before do
    connect_to_redis!
    DrbQueue.start!
  end

  after do
    DrbQueue.kill_server!
    Redis.current.flushall
  end

  class SetKeyToValueWorker
    def self.perform(key, value, sleep_before_working = false)
      sleep 0.1 if sleep_before_working
      Redis.current.set(key, value)
    end
  end

  context SetKeyToValueWorker do
    let(:key) { 'foo' }
    let(:value) { 'bar' }

    it 'should do work asynchronously' do
      DrbQueue.enqueue(SetKeyToValueWorker, key, value, :sleep_before_working)
      expect(Redis.current.get(key)).to be_nil
      sleep 0.2
      expect(Redis.current.get(key)).to eq(value)
    end

    it 'should do work in order' do
      DrbQueue.enqueue(SetKeyToValueWorker, key, 'nottherightanswer')
      DrbQueue.enqueue(SetKeyToValueWorker, key, value)
      sleep 0.2
      expect(Redis.current.get(key)).to eq(value)
    end
  end

  class SleepyWorker
    def self.perform
      sleep 100
    end
  end

  context SleepyWorker do
    it 'should not block regular execution' do
      expect(Benchmark.realtime { DrbQueue.enqueue(SleepyWorker) }).to be < 1
    end
  end
end
