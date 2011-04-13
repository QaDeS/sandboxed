if RUBY_PLATFORM == 'jruby'
  warn "Sandboxed is not supported on JRuby"
end

require 'sandboxed/compat'
require 'sandboxed/proc'
require 'sandboxed/fiber'

module Sandboxed
  module Modes
    class << self
      def ctx_only(level, ctx, args, &block)
        proc {
          $SAFE=level
          (ctx || eval("self", block.binding)).instance_exec(*args, &block)
        }.call
      end

      def overlay(level, ctx, args, &block)
        class << eval("self", block.binding)
          include ContextHolder
        end if ctx

        proc {
          $SAFE = level
          yield *args
        }.call
      end
    end
  end
  MODES = {:overlay => '1.8.6', :ctx_only => '1.8.7'}.reject{|m, v| v > RUBY_VERSION}
  MODE_PREFERENCE = [:overlay, :ctx_only] & MODES.keys

  class << self

    def default_mode
      @default_mode ||= MODE_PREFERENCE.first
    end
    def default_mode=(mode)
      @default_mode = check_mode(mode)
    end

    def safe(*args, &block)
      contexts = Thread.current[:__contexts_] ||= []
      opts = args.last.is_a?(Hash) ? args.pop : {}
      
      mode = opts.delete(:mode) || default_mode
      check_mode(mode)

      level = opts.delete(:level) || 4
      ctx = opts.delete(:context)
      args << opts unless opts.empty? # be nicer about passed in hashes

      contexts << ctx
      result = Modes.send(mode, level, ctx, args, &block)
      contexts.pop if ctx

      result
    end

    def safe_method(mdl, *ms)
      code = ms.map do |m|
        safe_m = "#{m}__safe_"
        <<-RUBY
          alias #{safe_m} #{m}
          def #{m}(*args, &block)
            result = SAFE_FIBER.resume([self, :#{safe_m}, args, block])
            result.is_a?(Exception) ? throw(result) : result  # TODO find a better way
          end
        RUBY
      end.join("\n")
      mdl.class_eval code
    end

  private
    def check_mode(m)
      mode = m.to_sym
      return mode if MODES.member?(mode)
      raise ArgumentError, "Sandbox mode '#{mode}' is not defined; must be one of #{MODES.keys.map.join(', ')}"
    end

  end

  private

  # initialize worker fiber for sandboxed execution
  SAFE_FIBER = Fiber.new do |msg|
    while true
      obj, m, args, block = msg
      begin
        msg = Fiber.yield(block ? obj.send(m, *args, &block) : obj.send(m, *args))
      rescue Exception => e
        msg = Fiber.yield(e)
      end
    end
  end.freeze

  module ContextHolder
    def method_missing(name, *args, &block)
      if ctx = Thread.current[:__contexts_].last
        if ctx.respond_to?(name)
          return block ? ctx.send(name, *args, &block) : ctx.send(name, *args)
        end
      end
      super
    end
  end
end

if mode = ENV['SANDBOX']
  Sandboxed.default_mode = mode
end

module Kernel
  def safe(*args, &block)
    Sandboxed.safe *args, &block
  end
  def safe_method(*names)
    Sandboxed.safe_method self, *names
  end
end

