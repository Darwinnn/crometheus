module Crometheus
  # An instantaneous datum from a Metric. In general, `Metric` types
  # should yield one or more of these when #sample is colled.
  # Collector#collect aggregates Samples from associated `Metric`s,
  # and `Registry` interpolates their values into an appropriate
  # exposition format.
  #
  # Each Sample corresponds to one line item in the exposited metric
  # data. Thus, Counters and Gauges always yield a single Sample, while
  # Summaries and Histograms yield more depending on how many
  # buckets/quantiles are configured.
  #
  # A `Sample` like this:
  # ```
  # Sample.new(12.0, labels: {:fruit => "banana"}, suffix: "_fruit")
  # ```
  # will produce an exported metric line like this:
  # ```text
  # metric_name_fruit{fruit="banana"} 12.0
  # ```
  struct Sample
    property suffix : String
    property value : Float64
    property labels : Hash(Symbol, String)

    # property timestamp : Int64?
    # https://groups.google.com/d/msg/prometheus-developers/p2SBdIbT4lQ/YYSQcpS0AgAJ

    def initialize(@value, @labels = {} of Symbol => String, @suffix = "")
    end

    def to_s(io)
      io <<  '[' << @suffix << @labels << ' ' << @value << ']'
    end

  end
end
