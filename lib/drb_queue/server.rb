require "uuid"
require "thread"

module DrbQueue
  class Server
    NotStarted = Class.new(StandardError)
    AlreadyStarted = Class.new(StandardError)

    def initialize
      @queue = Queue.new

      start_worker!
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

    def start_worker!
      Thread.new do
        while work = queue.pop
          work.call
        end
      end
    end

    private
    attr_reader :queue
  end
end
