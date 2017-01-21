require "./metric"

module Crometheus
  # Gauge is a `Metric` type that stores a single value internally.
  # This value can be modified arbitrarily via instance methods.
  #
  # Gauge should generally not be instantiated directly. Instantiate
  # `Collector`(Gauge) instead.
  class Gauge < Metric
    @value : Float64 = 0.0

    # Fetches @value.
    def get
      @value
    end

    def set(x : Int | Float)
      @value = x.to_f64
    end

    def inc(x : Int | Float = 1.0)
      set @value + x.to_f64
    end

    def dec(x : Int | Float = 1.0)
      set @value - x.to_f64
    end

    def set_to_current_time
      set Time.now.epoch_f
    end

    def measure_runtime
      t0 = Time.now
      yield
      t1 = Time.now
      set((t1 - t0).to_f)
    end

    def count_concurrent
      inc
      yield
      dec
    end

    def type
      "gauge"
    end
  end
end
