require "./metric"

module Crometheus
  # Gauge is a `Metric` type that stores a single value internally.
  # This value can be modified freely via instance methods.
  # ```
  # require "crometheus/gauge"
  #
  # body_temperature = Crometheus::Gauge.new(
  #   :body_temperature, "Human body temperature")
  # body_temperature.set 98.6
  #
  # # Running a fever...
  # body_temperature.inc 1.8
  # # Partial recovery
  # body_temperature.dec 0.6
  #
  # body_temperature.get # => 99.8
  # ```
  class Gauge < Metric
    @value : Float64 = 0.0

    # Fetches the gauge value.
    def get
      @value
    end

    # Sets the gauge value to the given number.
    def set(x : Int | Float)
      @value = x.to_f64
    end

    # Increments the gauge value by the given number, or 1.0.
    def inc(x : Int | Float = 1.0)
      set @value + x.to_f64
    end

    # Decrements the gauge value by the given number, or 1.0.
    def dec(x : Int | Float = 1.0)
      set @value - x.to_f64
    end

    # Sets the gauge value to the current UNIX timestamp.
    def set_to_current_time
      set Time.utc.to_unix_f
    end

    # Yields, then sets the gauge value to the block's runtime.
    def measure_runtime
      t0 = Time.utc
      begin
        yield
      ensure
        t1 = Time.utc
        set((t1 - t0).to_f)
      end
    end

    # Increments the gauge value, yields, then decrements the gauge
    # value. Wrap your event handlers with this to find out how many
    # events are being processed at a time.
    def count_concurrent
      inc
      yield
    ensure
      dec
    end

    # Returns `Type::Gauge`. See `Metric.type`.
    def self.type
      Type::Gauge
    end

    # Yields a single Sample bearing the gauge value.
    # See `Metric#samples`.
    def samples(&block : Sample -> Nil) : Nil
      yield Sample.new(@value)
    end
  end
end
