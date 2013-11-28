module DRbQueue
  class Configuration
    attr_accessor :socket_location, :num_workers, :logger

    def initialize
      self.socket_location = '/tmp/drb_queue'
      self.num_workers = 1
      self.logger = Logger.new(STDOUT)
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
