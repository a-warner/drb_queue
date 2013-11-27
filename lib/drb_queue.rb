require "drb_queue/version"
require 'drb/drb'
require 'drb/unix'
require "fileutils"

module DrbQueue
  extend self

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
    @pid = fork_server
    @started = true
  end

  def configure
    raise ConfiguredAfterStarted, "You must configure #{self.name} BEFORE starting the server" if started?

    yield configuration
  end

  def kill_server!
    return unless started?

    Process.kill('KILL', pid)
    Process.wait
    FileUtils.rm(socket_location) if File.exist?(socket_location)
  end

  private
  attr_reader :pid, :server

  def fork_server
    execute_before_fork_callbacks

    fork do
      execute_after_fork_callbacks

      DRb.start_service(server_uri, Server.new)
      DRb.thread.join
    end.tap do |pid|
      tries = 0

      begin
        @server = DRbObject.new_with_uri(server_uri)
        @server.ping
      rescue DRb::DRbConnError => e
        raise if tries > 3
        tries += 1
        sleep 0.2
        retry
      end

      at_exit do
        kill_server!
      end
    end
  end

  def execute_before_fork_callbacks
    configuration.before_fork_callbacks.each(&:call)
  end

  def execute_after_fork_callbacks
    configuration.after_fork_callbacks.each(&:call)
  end

  def configuration
    @configuration ||= Configuration.new
  end

  def server_uri
    "drbunix:#{socket_location}"
  end

  def socket_location
    "/tmp/drbqueue"
  end
end
