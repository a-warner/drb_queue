require "uuid"

module DrbQueue
  class Server
    NotStarted = Class.new(StandardError)

    def enqueue(worker, *args)
      worker.perform(*args)
      uuid.generate
    end

    def uuid
      @uuid ||= UUID.new
    end

    def ping
      'pong'
    end
  end
end
