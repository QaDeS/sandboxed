module Kernel
  unless method_defined?(:untrust)
    alias untrust taint
  end
end
