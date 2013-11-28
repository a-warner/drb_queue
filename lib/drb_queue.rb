require "drb_queue/version"
require 'drb/drb'
require 'drb/unix'
require "fileutils"
require 'timeout'
require 'json'

module DRbQueue
  extend self
  extend Forwardable

  autoload :Server, 'drb_queue/server'
  autoload :Configuration, 'drb_queue/configuration'

  ConfiguredAfterStarted = Class.new(StandardError)

  attr_reader :started
  alias_method :started?, :started

  def enqueue(worker, *args)
    raise Server::NotStarted, "You must start the server first" unless started?
    raise ArgumentError, "#{worker} is not a module" unless worker.is_a?(Module)
    raise ArgumentError, "#{worker} does not respond to perform" unless worker.respond_to?(:perform)

    server.enqueue(worker, *args)
  end

  def start!
    raise Server::AlreadyStarted, "The server is already started" if started?

    synchronize do
      return if started?

      @pid = fork_server
      @started = true
    end
  end

  def configure
    raise ConfiguredAfterStarted, "You must configure #{self.name} BEFORE starting the server" if started?

    synchronize { yield configuration }
  end

  def shutdown!(immediately = false)
    return unless started?

    synchronize do
      return unless started?

      Process.kill(immediately ? 'KILL' : 'TERM', pid)

      begin
        ::Timeout.timeout(20) { Process.wait }
      rescue Timeout::Error
        Process.kill('KILL', pid)
        Process.wait
        logger.error("#{self}: forced shutdown")
      ensure
        FileUtils.rm(socket_location) if File.exist?(socket_location)
        @started = false
        @pid = nil
      end
    end
  end

  private
  attr_reader :pid, :server

  def fork_server
    execute_before_fork_callbacks

    fork do
      execute_after_fork_callbacks

      server = Server.new(configuration)
      DRb.start_service(server_uri, server)

      shutting_down = false
      trap('TERM') { shutting_down = true }
      sleep 0.1 until shutting_down

      server.shutdown!
      DRb.stop_service
    end.tap do |pid|
      tries = 0

      begin
        @server = DRbObject.new_with_uri(server_uri)
        @server.ping
      rescue DRb::DRbConnError => e
        raise Server::UnableToStart.new("Couldn't start up the queue server", e) if tries > 3
        tries += 1
        sleep 0.2
        retry
      end

      at_exit { shutdown! }
    end
  end

  def execute_before_fork_callbacks
    before_fork_callbacks.each(&:call)
  end

  def execute_after_fork_callbacks
    after_fork_callbacks.each(&:call)
  end

  def configuration
    @configuration ||= Configuration.new
  end
  def_delegators :configuration, :server_uri, :socket_location, :before_fork_callbacks, :after_fork_callbacks, :num_workers, :logger

  def synchronize(&block)
    synchronization_mutex.synchronize(&block)
  end

  def synchronization_mutex
    @synchronization_mutex ||= Mutex.new
  end
end
