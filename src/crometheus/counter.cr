require "./metric"

module Crometheus
  # Counter is a `Metric` type that stores a single value internally.
  # This value can be reset to zero, but otherwises increases
  # monotonically, and only when #inc is called.
  #
  # Counter should generally not be instantiated directly. Instantiate
  # `Collector`(Counter) instead.
  class Counter < Metric
    @value = 0.0

    # Fetches @value.
    def get
      @value
    end

    # Increments @value by the given amount.
    def inc(x : Int | Float = 1.0)
      @value += x
    end

    # Sets @value to 0.0.
    def reset
      @value = 0.0
    end

    # Yields the block, calling #inc if an exception is raised.
    # The exception is always re-raised.
    #
    # Example:
    # ```
    # require "../src/crometheus/counter"
    # require "../src/crometheus/collector"
    # include Crometheus
    # def unsafe_code
    #   x = 1 / [1, 0].sample
    # end
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

    def type
      "counter"
    end

    # Increments the given counter when the block raises an exception
    # matching the given type. Once
    # https://github.com/crystal-lang/crystal/issues/2060 is resolved,
    # this macro will be deprecated and its functionality folded into
    # #count_exceptions.
    macro count_exceptions_of_type(counter, ex_type)
      begin
        {{yield}}
      rescue ex : {{ex_type}}
        counter.inc
        raise ex
      end
    end

  end
end
