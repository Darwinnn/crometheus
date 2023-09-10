module Crometheus
  # An instantaneous datum from a metric. `Metric` types
  # should yield one or more of these when `Metric#sample` is called.
  # `Registry` interpolates their values into an appropriate exposition
  # format.
  #
  # Each Sample corresponds to one line item in the exposed metric
  # data. Thus, counters and gauges always yield a single sample, while
  # summaries and histograms yield more depending on how many
  # buckets/quantiles are configured.
  #
  # A `Metric` named `:fruit` that yields a `Sample` like this:
  # ```
  # Sample.new(12.0, labels: {:species => "banana"}, suffix: "count")
  # ```
  # will produce an exported metric line like this:
  # ```text
  # fruit_count{species="banana"} 12.0
  # ```
  struct Sample
    property suffix : String
    property value : Float64 | Int64
    property labels : Hash(Symbol, String)

    # property timestamp : Int64?
    # https://groups.google.com/d/msg/prometheus-developers/p2SBdIbT4lQ/YYSQcpS0AgAJ

    def initialize(@value, @labels = {} of Symbol => String, @suffix = "")
    end
  end
end
