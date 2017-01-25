require "./metric"
require "./stringify"

module Crometheus
  class Histogram < Metric
    @@default_buckets = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1,
                         2.5, 5, 10]

    @buckets = {} of Float64 => Float64
    @sum = 0.0

    def initialize(labels = {} of Symbol => String, buckets : Array(Float | Int) = @@default_buckets)
      super(labels)
      buckets.each do |le|
        @buckets[le.to_f64] = 0.0
      end
      @buckets[Float64::INFINITY] = 0.0
    end

    def observe(value)
      @buckets.each_key do |le|
        @buckets[le] += 1.0 if value <= le
      end
      @sum += value
    end

    def count : Float64
      @buckets[Float64::INFINITY]
    end

    def sum : Float64
      @sum
    end

    def buckets : Hash(Float64, Float64)
      @buckets
    end

    def reset
      @buckets.each_key do |le|
        @buckets[le] = 0.0
      end
      @sum = 0.0
    end

    def measure_runtime(&block)
      t0 = Time.now
      begin
        yield
      ensure
        t1 = Time.now
        observe((t1 - t0).to_f)
      end
    end

    def samples(&block : Sample -> Nil)
      yield make_sample(@buckets[Float64::INFINITY], suffix: "_count")
      yield make_sample(@sum, suffix: "_sum")
      @buckets.each do |le, value|
        yield make_sample(value, labels: {:le => Crometheus.stringify(le).to_s})
      end
    end

    def type
      "histogram"
    end

    def self.linear_buckets(start, step, count) : Array(Float64)
      ary = [] of Float64
      start = start.to_f64
      step = step.to_f64
      (count - 1).times do |ii|
        ary << start + step * ii
      end
      return ary << Float64::INFINITY
    end

    def self.geometric_buckets(start, factor, count) : Array(Float64)
      ary = [] of Float64
      start = start.to_f64
      factor = factor.to_f64
      (count - 1).times do |ii|
        ary << start * factor ** ii
      end
      return ary << Float64::INFINITY
    end

    def self.valid_label?(label : Symbol)
      return false if :le == label
      return super
    end
  end
end
