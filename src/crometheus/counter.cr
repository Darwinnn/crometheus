require "./metric"

module Crometheus
  # Counter is a `Metric` type that stores a single value internally.
  # This value can be reset to zero, but otherwises increases
  # monotonically, and only when `#inc` is called.
  #
  # `Counter` should generally not be instantiated directly. Instantiate
  # `Collector(Counter)` instead.
  #
  #```
  # flowers_planted = Crometheus::Collector(Crometheus::Counter).new(
  #   :flowers_planted, "Number of flowers planted")
  # flowers_planted.inc 10
  # flowers_planted.inc
  # flowers_planted.inc
  # flowers_planted.get # => 12.0
  #```
  class Counter < Metric
    @value = 0.0

    # Fetches the current counter value.
    def get
      @value
    end

    # Increments the counter value by the given number, or `1.0`.
    def inc(x : Int | Float = 1.0)
      raise ArgumentError.new "Counter increments must be non-negative" if x < 0
      @value += x
    end

    # Sets the counter value to `0.0`.
    def reset
      @value = 0.0
    end

    # Yields to the block, calling #inc if an exception is raised.
    # The exception is always re-raised.
    #
    # Example:
    # ```
    # require "crometheus/counter"
    # require "crometheus/collector"
    # include Crometheus
    #
    # def unsafe_code
    #   x = 1 / [1, 0].sample
    # end
    #
    # counter = Collector(Counter).new :example, ""
    # 100.times do
    #   begin
    #     counter.count_exceptions {unsafe_code}
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
      yield make_sample(@value)
    end

    # Returns `:counter`. See `Metric.type`.
    def self.type
      :counter
    end

    # Yields to the block, incrementing the given counter when an
    # exception matching the given type is raised. At a future date,
    # this macro will be deprecated and its functionality folded into
    # `#count_exceptions`.
    macro count_exceptions_of_type(counter, ex_type, &block)
    # https://github.com/crystal-lang/crystal/issues/2060
      begin
        {{yield}}
      rescue ex : {{ex_type}}
        counter.inc
        raise ex
      end
    end

  end
end
