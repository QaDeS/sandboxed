if RUBY_PLATFORM == 'jruby'
  warn "Sandboxed is not supported on JRuby"
end

require 'forwardable'
require 'sandboxed/compat'
require 'sandboxed/proc'
require 'sandboxed/fiber'

module Sandboxed
  module ContextHolder
    class << self
      extend Forwardable
      def contexts
        Thread.current[:__contexts_] ||= []
      end
      def_delegator :contexts, :last, :current
      def_delegator :contexts, :<<, :push
      def_delegator :contexts, :pop
    end

    def method_missing(name, *args, &block)
      if ctx = ContextHolder.contexts.last
        if ctx.respond_to?(name)
          return block ? ctx.send(name, *args, &block) : ctx.send(name, *args)
        end
      end
      super
    end
  end

  module Modes
    class << self

      if RUBY_VERSION < '1.8.7'
        require 'rubygems'
        require 'sourcify'
        def bound(level, ctx, args, &block)
          time = Time.now
          method_name = "__bind_#{time.to_i}_#{time.usec}"
          class << ctx; self; end.class_eval <<-RUBY
            def #{method_name}(*args)
              #{block.to_ruby}.call(*args)
            end
          RUBY
          result = proc {
            $SAFE=level
            ctx.send method_name, *args
          }.call
          class << ctx; self; end.class_eval do
            remove_method(method_name)
          end
          result
        end
      else
        # less overhead, but only available on 1.8.7+
        def bound(level, ctx, args, &block)
          proc {
            $SAFE=level
            ctx.instance_exec(*args, &block)
          }.call
        end
      end

      def overlay(level, ctx, args, &block)
        # TODO support :only and :except options
        ContextHolder.push ctx
        begin
          class << eval("self", block.binding)
            include ContextHolder
          end if ctx

          proc {
            $SAFE = level
            yield *args
          }.call
        ensure
          ContextHolder.pop
        end
      end
    end
  end
  MODES = [:bound, :overlay]

  class << self

    def default_mode
      @default_mode ||= MODES.first
    end
    def default_mode=(mode)
      @default_mode = check_mode(mode)
    end

    def safe(*args, &block)
      opts = args.last.is_a?(Hash) ? args.pop : {}
      
      mode = opts.delete(:mode) || default_mode
      check_mode(mode)

      level = opts.delete(:level) || 4
      ctx = opts.delete(:context)
      args << opts unless opts.empty? # be nicer about passed in hashes

      result = Modes.send(mode, level, ctx, args, &block)

      result
    end

    def safe_method(mdl, *ms)
      code = ms.map do |m|
        safe_m = "#{m}__safe_"
        <<-RUBY
          alias #{safe_m} #{m}
          def #{m}(*args, &block)
            return #{safe_m}(*args, &block) if $SAFE == 0  # performance shortcut
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
      raise ArgumentError, "Sandbox mode '#{mode}' is not defined; must be one of #{MODES.join(', ')}"
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

end

if mode = ENV['SANDBOXED']
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

