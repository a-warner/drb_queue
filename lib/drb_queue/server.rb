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

    def initialize(configuration)
      @logger = configuration.logger
      @error_handler = configuration.error_handler
      @immediate = configuration.immediate
      @queue = Queue.new

      start_workers(configuration.num_workers)
    end

    def enqueue(worker, *args)
      uuid.generate.tap do |id|
        work = lambda { worker.perform(*args) }

        if immediate?
          work.call
        else
          queue << work
        end
      end
    end

    def uuid
      @uuid ||= UUID.new
    end

    def ping
      'pong'
    end

    private
    attr_reader :queue, :logger, :error_handler, :immediate
    alias_method :immediate?, :immediate

    def start_workers(num)
      num.times { start_worker }
    end

    def start_worker
      Thread.new do
        while work = queue.pop
          begin
            work.call
          rescue => e
            error_handler.call(e)
            start_worker
            break
          end
        end
      end
    end
  end
end
