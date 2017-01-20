# A Gauge metric
# You want to instantiate Collection(Gauge), not this.
require "./metric"

module Crometheus
  class Gauge < Metric
    @value : Float64 = 0.0

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

    def measure
      t0 = Time.now
      yield
      t1 = Time.now
      set((t1 - t0).to_f)
    end

  end
end
