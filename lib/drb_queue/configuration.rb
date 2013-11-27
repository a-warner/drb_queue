module DrbQueue
  class Configuration
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
  end
end
