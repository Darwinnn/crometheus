require "./metric"

module Crometheus
  class Counter < Metric
    @value = 0.0

    def get
      @value
    end

    def inc(x : Int | Float = 1.0)
      @value += x
    end

    def reset
      @value = 0.0
    end
  end
end
