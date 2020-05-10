module Crometheus
  # An exception raised when a metric fails to generate a usable value.
  class Exceptions::InstrumentationError < Exception
  end
end
