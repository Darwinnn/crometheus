require "./metric"
require "./registry"

module Crometheus
  # Counter is a `Metric` type that stores a single value internally.
  # This value can be reset to zero, but otherwises increases
  # monotonically, and only when `#inc` is called.
  # ```
  # require "crometheus/counter"
  #
  # flowers_planted = Crometheus::Counter.new(
  #   :flowers_planted, "Number of flowers planted")
  # flowers_planted.inc 10
  # flowers_planted.inc
  # flowers_planted.inc
  # flowers_planted.get # => 12.0
  # ```
  class Counter < Metric
    @value = 0.0

    # Fetches the current counter value.
    def get
      @value
    end

    # Increments the counter value by the given number, or `1.0`.
    def inc(x : Int8 | Int16 | Int32 | Int64 | Int128 | Float32 | Float64 = 1.0)
      raise ArgumentError.new "Counter increments must be non-negative" if x < 0
      @value += x
    end

    # Sets the counter value to `0.0`.
    def reset
      @value = 0.0
    end

    # Yields to the block, calling #inc if an exception is raised.
    # The exception is always re-raised.
    # ```
    # require "crometheus/counter"
    # include Crometheus
    #
    # def risky_code
    #   x = 1 / [1, 0].sample
    # end
    #
    # counter = Counter.new :example, ""
    # 100.times do
    #   begin
    #     counter.count_exceptions { risky_code }
    #   rescue DivisionByZero
    #   end
    # end
    # puts counter.get # approximately 50
    # ```
    def count_exceptions
      yield
    rescue ex
      inc
      raise ex
    end

    # Yields a single Sample bearing the counter value. See
    # `Metric#samples`.
    def samples(&block : Sample -> Nil) : Nil
      yield Sample.new(@value)
    end

    # Returns `Type::Counter`. See `Metric.type`.
    def self.type
      Type::Counter
    end

    # Yields to the block, incrementing the given counter when an
    # exception matching the given type is raised. At a future date,
    # this macro will be deprecated and its functionality folded into
    # `#count_exceptions`.
    # Pending https://github.com/crystal-lang/crystal/issues/2060.
    macro count_exceptions_of_type(counter, ex_type, &block)
      begin
        {{yield}}
      rescue ex : {{ex_type}}
        {{counter}}.inc
        raise ex
      end
    end
  end
end
