require "./metric"
require "./stringify"

module Crometheus
  # `Histogram` is a `Metric` type that tracks how many observations
  # fit into a series of ranges, or buckets. Each bucket is defined by
  # its upper bound. Whenever `#observe` is called, the value of each
  # bucket with a bound equal to or greater than the observed value is
  # incremented. A running sum of all observed values is also tracked.
  #
  # `Histogram` should generally not be instantiated directly.
  # Instantiate `Collector(Histogram)` instead.
  class Histogram < Metric
    @@default_buckets = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1,
                         2.5, 5, 10]

    # A mapping of upper bounds to bucket values.
    getter buckets = {} of Float64 => Float64

    # A running sum of all observed values.
    getter sum = 0.0

    # In addition to the standard arguments for `Metric#initialize`,
    # takes an array that defines the range of each bucket. The
    # `.linear_buckets` and `.geometric_buckets` convenience methods may
    # be used to generate an appropriate array. A bucket for Infinity
    # will be added if it is not already part of the array. If left
    # unspecified, buckets will default to
    # `[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]`.
    def initialize(labels = {} of Symbol => String,
                   buckets : Array(Float | Int) = @@default_buckets)
      super(labels)
      buckets.each do |le|
        @buckets[le.to_f64] = 0.0
      end
      @buckets[Float64::INFINITY] = 0.0
    end

    # Increments the value of all buckets whose range includes `value`.
    # Also increases `sum` by `value`.
    def observe(value)
      @buckets.each_key do |le|
        @buckets[le] += 1.0 if value <= le
      end
      @sum += value
    end

    # Returns the value of the Infinity bucket. This is equal to the
    # total number of observations performed by this histogram.
    def count : Float64
      @buckets[Float64::INFINITY]
    end

    # Resets all bucket values, as well as `sum`, to `0.0`.
    def reset
      @buckets.each_key do |le|
        @buckets[le] = 0.0
      end
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

    # Yields one `Sample` for each bucket, in addition to one for
    # `count` (equal to the infinity bucket) and one for `sum`. See
    # `Metric#samples`.
    def samples(&block : Sample -> Nil)
      yield make_sample(@buckets[Float64::INFINITY], suffix: "_count")
      yield make_sample(@sum, suffix: "_sum")
      @buckets.each do |le, value|
        yield make_sample(value, labels: {:le => Crometheus.stringify(le).to_s})
      end
    end

    # Returns `:histogram`. See `Metric.type`.
    def self.type
      :histogram
    end

    # Returns an array of linearly-increasing bucket upper bounds
    # suitable for passing into the constructor of `Histogram`.
    # `bucket_count` includes the Infinity bucket.
    # ```
    # require "crometheus/collector"
    # require "crometheus/histogram"
    # include Crometheus
    #
    # hist = Collector(Histogram).new(:evens, "even teens",
    #   buckets: Histogram.linear_buckets(12, 2, 5))
    #
    # hist.buckets # => {12.0 => 0.0, 14.0 => 0.0, 16.0 => 0.0,
    #              #     18.0 => 0.0, Infinity => 0.0}
    # ```
    def self.linear_buckets(start, step, bucket_count) : Array(Float64)
      ary = [] of Float64
      start = start.to_f64
      step = step.to_f64
      bucket_count.times do |ii|
        ary << start + step * ii
      end
      return ary << Float64::INFINITY
    end

    # Returns an array of geometrically-increasing bucket upper bounds
    # suitable for passing into the constructor of `Histogram`.
    # `bucket_count` includes the Infinity bucket.
    # ```
    # require "crometheus/collector"
    # require "crometheus/histogram"
    # include Crometheus
    #
    # hist = Collector(Histogram).new(:powers, "powers of two",
    #   buckets: Histogram.geometric_buckets(1, 2, 5))
    #
    # hist.buckets # => {1.0 => 0.0, 2.0 => 0.0, 4.0 => 0.0,
    #              #     8.0 => 0.0, Infinity => 0.0}
    # ```
    def self.geometric_buckets(start, factor, bucket_count) : Array(Float64)
      ary = [] of Float64
      start = start.to_f64
      factor = factor.to_f64
      bucket_count.times do |ii|
        ary << start * factor ** ii
      end
      return ary << Float64::INFINITY
    end

    # In addition to the standard `Metric.valid_label?` behavior,
    # returns `false` if a label is `:le`. Histograms reserve this label
    # for bucket upper bounds.
    def self.valid_label?(label : Symbol)
      return false if :le == label
      return super
    end
  end
end
