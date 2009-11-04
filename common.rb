module Markus
  # something we don't expect to go wrong
  class HardException < Exception
  end

  # user input errors
  class SoftException < Exception
  end
end
