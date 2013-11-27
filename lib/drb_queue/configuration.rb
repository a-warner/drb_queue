module DrbQueue
  class Configuration
    attr_accessor :socket_location
    attr_accessor :num_workers

    def initialize
      self.socket_location = '/tmp/drb_queue'
      self.num_workers = 1
    end

    def after_fork(&block)
      after_fork_callbacks << block
    end

    def before_fork(&block)
      before_fork_callbacks << block
    end

    def after_fork_callbacks
      @after_fork_callbacks ||= []
    end

    def before_fork_callbacks
      @before_fork_callbacks ||= []
    end

    def server_uri
      "drbunix:#{socket_location}"
    end
  end
end
