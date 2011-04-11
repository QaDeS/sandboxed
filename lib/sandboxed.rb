require 'sandboxed/compat'
require 'sandboxed/proc'
require 'sandboxed/fiber'

module Kernel

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

  def safe(*args, &block)
    opts = args.last.is_a?(Hash) ? args.pop : {}
    level = opts.delete(:level) || 4
    ctx = opts.delete(:context) || eval('self', block.binding) # rebind to actual declaring object
    args << opts unless opts.empty? # be nicer about passed in hashes

    bound = block.bind(ctx) # TODO 1.8 compat is missing out here. How to?
    Fiber.new do |l, c, b, a|
      $SAFE = l
      b.call *a
    end.resume(level, ctx, bound, args)
  end

  def safe_method(*ms)
    ms.each do |m|
      safe_m = :"#{m}__safe_"
      alias_method safe_m, m
      define_method m do |*args, &block|
        result = SAFE_FIBER.resume([self, safe_m, args, block])
        result.is_a?(Exception) ? throw(result) : result  # TODO find a better way
      end
    end
  end

end


