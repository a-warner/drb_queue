require "drb_queue/version"
require 'drb/drb'
require 'drb/unix'
require "fileutils"

module DrbQueue
  extend self
  extend Forwardable

  autoload :Server, 'drb_queue/server'
  autoload :Configuration, 'drb_queue/configuration'

  ConfiguredAfterStarted = Class.new(StandardError)

  attr_reader :started
  alias_method :started?, :started

  def enqueue(*args)
    raise Server::NotStarted, "You must start the server first" unless started?

    server.enqueue(*args)
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

  def kill_server!
    return unless started?

    synchronize do
      return unless started?

      Process.kill('KILL', pid)
      Process.wait
      FileUtils.rm(socket_location) if File.exist?(socket_location)

      @started = false
      @pid = nil
    end
  end

  private
  attr_reader :pid, :server

  def fork_server
    execute_before_fork_callbacks

    fork do
      execute_after_fork_callbacks

      DRb.start_service(server_uri, Server.new(logger, num_workers))
      DRb.thread.join
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

      at_exit { kill_server! }
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
