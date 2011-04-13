# Poor Man's Fiber (API compatible Thread based Fiber implementation for Ruby 1.8)
# Based on https://gist.github.com/4631 (c) 2008 Aman Gupta (tmm1)

unless defined? Fiber
require 'thread'

  class FiberError < StandardError; end

  class Fiber < Thread
    def initialize
      raise ArgumentError, 'new Fiber requires a block' unless block_given?
      @yield = Queue.new
      @resume = Queue.new

      super{ @yield.push [yield(*@resume.pop)] }
      abort_on_exception = true
    end

    def resume *args
      raise FiberError, 'dead fiber called' unless alive?
      @resume.push(args)
      result = @yield.pop
      result.size > 1 ? result : result.first
    end
    
    def yield *args
      @yield.push(args)
      result = @resume.pop
      result.size > 1 ? result : result.first
    end
    
    def self.yield *args
      raise FiberError, "can't yield from root fiber" unless fiber = Thread.current
      fiber.yield(*args)
    end

    def inspect
      "#<#{self.class}:0x#{self.object_id.to_s(16)}>"
    end
  end
end

