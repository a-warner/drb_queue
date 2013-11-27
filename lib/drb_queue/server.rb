require "uuid"
require "thread"

module DrbQueue
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

    def initialize(logger, num_workers)
      @logger = logger
      @queue = Queue.new

      start_workers(num_workers)
    end

    def enqueue(worker, *args)
      uuid.generate.tap do |id|
        queue << lambda { worker.perform(*args) }
      end
    end

    def uuid
      @uuid ||= UUID.new
    end

    def ping
      'pong'
    end

    def start_workers(num)
      num.times do
        Thread.new do
          while work = queue.pop
            begin
              work.call
            rescue => e
              logger.error(([e.message] + e.backtrace).join("\n"))
            end
          end
        end
      end
    end

    private
    attr_reader :queue, :logger
  end
end
