require 'spec_helper'

describe DRbQueue do
  it { should_not be_nil }

  def connect_to_redis!
    Redis.current = Redis::Namespace.new(described_class.to_s, :redis => Redis.new(:db => 8))
  end

  before(:all) do
    DRbQueue.configure do |c|
      c.after_fork do
        connect_to_redis!
      end
    end
  end

  def per_test_configuration(config); end

  before do
    connect_to_redis!

    DRbQueue.configure do |c|
      @old_config = c.dup
      per_test_configuration(c)
    end

    DRbQueue.start!
  end

  after do
    DRbQueue.shutdown!
    DRbQueue.instance_variable_set('@configuration', @old_config)
    Redis.current.flushall
  end

  class SetKeyToValueWorker
    def self.perform(key, value, options = {})
      sleep options[:sleep_time_before_working] if options[:sleep_time_before_working]
      Redis.current.set(key, value)
    end
  end

  context SetKeyToValueWorker do
    let(:key) { 'foo' }
    let(:value) { 'bar' }

    it 'should do work asynchronously' do
      DRbQueue.enqueue(SetKeyToValueWorker, key, value, :sleep_time_before_working => 0.1)
      expect(Redis.current.get(key)).to be_nil
      sleep 0.2
      expect(Redis.current.get(key)).to eq(value)
    end

    it 'should do work in order' do
      DRbQueue.enqueue(SetKeyToValueWorker, key, 'nottherightanswer')
      DRbQueue.enqueue(SetKeyToValueWorker, key, value)
      sleep 0.2
      expect(Redis.current.get(key)).to eq(value)
    end

    context 'in parallel' do
      def per_test_configuration(config)
        config.num_workers = 5
      end

      it 'should do work in parallel' do
        time = Benchmark.realtime do
          5.times { |i| DRbQueue.enqueue(SetKeyToValueWorker, i, i.to_s, :sleep_time_before_working => 0.1) }
          sleep 0.2
          5.times { |i| expect(Redis.current.get(i)).to eq(i.to_s) }
        end

        expect(time).to be < 0.4
      end
    end
  end

  class SleepyWorker
    def self.perform
      sleep 100
    end
  end

  context SleepyWorker do
    it 'should not block regular execution' do
      expect(Benchmark.realtime { DRbQueue.enqueue(SleepyWorker) }).to be < 1
    end
  end

  class ExceptionWorker
    def self.perform
      raise "Get me outta here!"
    end
  end

  context ExceptionWorker do
    it 'should continue operating normally' do
      DRbQueue.enqueue(ExceptionWorker)
      sleep 0.1
      DRbQueue.enqueue(SetKeyToValueWorker, 'a', 'b')
      sleep 0.1
      expect(Redis.current.get('a')).to eq('b')
    end

    def per_test_configuration(config)
      config.on_error do |e|
        Redis.current.set('error', e.message)
      end
    end

    it 'allows custom exception handlers' do
      DRbQueue.enqueue(ExceptionWorker)
      sleep 0.1
      expect(Redis.current.get('error')).not_to be_nil
    end
  end

  context 'immediate mode' do
    def per_test_configuration(config)
      config.immediate!
    end

    it 'should do work synchronously' do
      DRbQueue.enqueue(SetKeyToValueWorker, 'immediate', 'results', :sleep_time_before_working => 0.1)
      expect(Redis.current.get('immediate')).to eq('results')
    end
  end

  context 'error cases' do
    it 'should blow up if something besides a module is passed in' do
      expect { DRbQueue.enqueue('hahaha', 1, 2) }.to raise_error ArgumentError
    end

    it 'should blow up unless the module responds to perform' do
      expect { DRbQueue.enqueue(Class.new) }.to raise_error ArgumentError
    end
  end
end
