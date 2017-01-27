require "./metric"

module Crometheus
  # `Summary` is a metric type that keeps a running total of
  # observations. Every time `#observe` is called, `sum` is incremented
  # by the given value, and `count` is incremented by one.
  #
  # Quantiles are not currently supported.
  #
  # `Summary` should generally not be instantiated directly. Instantiate
  # `Collector(Summary)` instead.
  #```
  # cargo_weight = Crometheus::Collector(Crometheus::Summary).new(
  #   :cargo_weight, "Weight of all boxes")
  # cargo_weight.observe 29.0
  # cargo_weight.observe 12.0
  # cargo_weight.observe 10.0
  #
  # mean_weight = cargo_weight.sum / cargo_weight.count  # => 17.0
  #```
  class Summary < Metric
    # The total number of observations.
    getter count = 0.0
    # The sum of all observed values.
    getter sum = 0.0

    # Increments `count` by one and `sum` by `value`.
    def observe(value : Int | Float)
      @count += 1.0
      @sum += value.to_f64
    end

    # Sets `count` and `sum` to `0.0`.
    def reset
      @count = 0.0
      @sum = 0.0
    end

    # Yields to the block, then passes the block's runtime to
    # `#observe`.
    def measure_runtime(&block)
      t0 = Time.now
      begin
        yield
      ensure
        t1 = Time.now
        observe((t1 - t0).to_f)
      end
    end

    # Yields two samples, one for `count` and one for `sum`.
    #
    # If you aren't writing your own metric types, don't worry about
    # this. If you are, see `Metric#samples`.
    def samples(&block : Sample -> Nil) : Nil
      yield make_sample(@count, suffix: "_count")
      yield make_sample(@sum, suffix: "_sum")
    end

    # Returns `:summary`. See `Metric.type`.
    def self.type
      :summary
    end

    # In addition to the standard `Metric.valid_label?` behavior,
    # returns `false` if a label is `:quantile`. Histograms reserve this
    # label for exporting quantiles (currently unsupported by
    # Crometheus).
    def self.valid_label?(label : Symbol)
      return false if :quantile == label
      return super
    end
  end
end
