require "uuid"
require "thread"

module DRbQueue
  class Server
    NotStarted = Class.new(StandardError)
    AlreadyStarted = Class.new(StandardError)

    class UnableToStart < StandardError
      attr_reader :cause
      def initialize(message, cause)
        super("#{message}: Cause is #{cause.inspect}")
        @cause = cause
      end
    end

    class Work < Struct.new(:worker, :args)
      def perform
        worker.perform(*args)
      end

      def self.unserialize(serialized)
        hash = JSON.parse(serialized)
        worker = hash['worker'].split('::').inject(Object) { |o, k| o.const_get(k) }

        new(worker, hash['args'])
      end

      def serialize
        {'worker' => worker.to_s, 'args' => args}.to_json
      end
    end

    def initialize(configuration)
      [:logger, :error_handler, :immediate].each do |p|
        __send__("#{p}=", configuration.__send__(p))
      end

      self.queue = Queue.new
      self.running = true

      self.store = configuration.construct_persistence_store

      start_workers(configuration.num_workers)

      if store
        store.each_persisted_work do |serialized_work|
          enqueue_work(Work.unserialize(serialized_work))
        end
      end
    end

    def enqueue(worker, *args)
      uuid.generate.tap do |id|
        enqueue_work(Work.new(worker, args))
      end
    end

    def uuid
      @uuid ||= UUID.new
    end

    def ping
      'pong'
    end

    def shutdown!
      self.running = false

      if store
        begin
          while work = queue.pop(:dont_block)
            store.persist(work)
          end
        rescue ThreadError => e
        rescue => e
          error_handler.call(e)
        end
      elsif queue.size > 0
        logger.error("Queue is non-empty and we're shutting down...probably better to configure a persistence store\n")
      end

      workers.each(&:join)
    end

    private
    attr_accessor :queue, :logger, :error_handler, :immediate, :store, :running
    alias_method :immediate?, :immediate
    alias_method :running?, :running

    def enqueue_work(work)
      if immediate?
        work.perform
      else
        queue << work
      end
    end

    def start_workers(num)
      num.times.map { start_worker }
    end

    def workers
      @workers ||= []
    end

    def start_worker
      thread = Thread.new do
        loop do
          begin
            break unless running?

            work = queue.pop(:non_blocking)
            work.perform
          rescue ThreadError => e
            sleep 0.05
          rescue => e
            error_handler.call(e)
            start_worker
            break
          end
        end

        workers.delete(thread)
      end

      workers << thread
    end
  end
end
