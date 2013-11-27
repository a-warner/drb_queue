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

    DrbQueue.start!
  end

  before do
    connect_to_redis!
  end

  after do
    Redis.current.flushall
  end

  class SetKeyToValueWorker
    def self.perform(key, value)
      Redis.current.set(key, value)
    end
  end

  context SetKeyToValueWorker do
    let(:key) { 'foo' }
    let(:value) { 'bar' }

    before do
      id = DrbQueue.enqueue(SetKeyToValueWorker, key, value)
      # DrbQueue.wait_for(id)
      sleep 1
    end

    subject { Redis.current.get(key) }
    it { should == value }
  end
end
