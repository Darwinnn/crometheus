require "./metric"

module Crometheus
  # A Metric type that stores a value internally. This value increases
  # monotonically, except that it can be reset to zero.
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

    # Increments @value when the block raises an exception.
    def count_exceptions(ex_type = Exception)
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
    macro count_exception_type(counter, ex_type)
      begin
        {{yield}}
      rescue ex : {{ex_type}}
        counter.inc
        raise ex
      end
    end

  end
end
