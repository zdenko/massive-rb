require_relative 'connection_pool/timed_stack'

#from https://github.com/mperham/connection_pool with slight modifications by me
#Copyright (c) 2011 Mike Perham -- released under the MIT license.
# Slightly modified; used with permission.

class ConnectionPool
  DEFAULTS = {size: 5, timeout: 5}

  class Error < RuntimeError
  end

  def self.wrap(options, &block)
    Wrapper.new(options, &block)
  end

  def initialize(options = {}, &block)
    raise ArgumentError, 'Connection pool requires a block' unless block

    options = DEFAULTS.merge(options)

    @size = options.fetch(:size)
    @timeout = options.fetch(:timeout)

    @available = TimedStack.new(@size, &block)
    @key = :"current-#{@available.object_id}"
    @key_count = :"current-#{@available.object_id}-count"
  end

if Thread.respond_to?(:handle_interrupt)

  # MRI
  def with(options = {})
    Thread.handle_interrupt(Exception => :never) do
      conn = checkout(options)
      begin
        Thread.handle_interrupt(Exception => :immediate) do
          yield conn
        end
      ensure
        checkin
      end
    end
  end

else

  # jruby 1.7.x
  def with(options = {})
    conn = checkout(options)
    begin
      yield conn
    ensure
      checkin
    end
  end

end

  def checkout(options = {})
    if ::Thread.current[@key]
      ::Thread.current[@key_count]+= 1
      ::Thread.current[@key]
    else
      ::Thread.current[@key_count]= 1
      ::Thread.current[@key]= @available.pop(options[:timeout] || @timeout)
    end
  end

  def checkin
    if ::Thread.current[@key]
      if ::Thread.current[@key_count] == 1
        @available.push(::Thread.current[@key])
        ::Thread.current[@key]= nil
      else
        ::Thread.current[@key_count]-= 1
      end
    else
      raise ConnectionPool::Error, 'no connections are checked out'
    end

    nil
  end

  def shutdown(&block)
    @available.shutdown(&block)
  end

  # Size of this connection pool
  def size
    @size
  end

  # Number of pool entries available for checkout at this instant.
  def available
    @available.length
  end

  private

  class Wrapper < ::BasicObject
    METHODS = [:with, :pool_shutdown]

    def initialize(options = {}, &block)
      @pool = options.fetch(:pool) { ::ConnectionPool.new(options, &block) }
    end

    def with(&block)
      @pool.with(&block)
    end

    def pool_shutdown(&block)
      @pool.shutdown(&block)
    end

    def pool_size
      @pool.size
    end

    def pool_available
      @pool.available
    end

    def respond_to?(id, *args)
      METHODS.include?(id) || with { |c| c.respond_to?(id, *args) }
    end

    def method_missing(name, *args, &block)
      with do |connection|
        connection.send(name, *args, &block)
      end
    end
  end
end