require "../collector"

module Crometheus
  class UnlabeledCollector(MetricType) < Crometheus::Collector
    getter metric : MetricType

    def initialize(name : Symbol,
                   docstring : String,
                   register_with : Crometheus::Registry? = Crometheus.default_registry,
                   **metric_params)
      @metric = MetricType.new(**metric_params)

      super(name, docstring, register_with)
    end

    # Fetches a metric (of type `T`) with the given labels, initializing
    # it with default values if necessary.
    # ```
    # require "crometheus/collector"
    # require "crometheus/gauge"
    # include Crometheus
    #
    # animals = Collector(Gauge).new(:animals, "animal counts")
    # animals[animal: "lion"].inc(3)
    # animals[animal: "bear"].inc(2)
    # ```
    # `Collector` automatically forwards
    # unrecognized methods to `self[]`, so this method is not necessary
    # to operate on the metric with the empty labelset.
    # ```
    # animals.set 10
    # animals.get # => 10
    # animals[].get # => 10
    # ```
    def []()
      @metric
    end

    # Returns the type of metric being collected. Will return one of
    # `:gauge`, `:counter`, `:histogram`, `:summary`, or `:untyped`.
    def type
      MetricType.type
    end

    # Iteratively calls `samples` on each metric in the collector,
    # yielding each received `Sample`. `Registry` uses this to iterate
    # over every sample in the collection. Users generally need not call
    # it.
    def collect(&block : Sample -> Nil)
      metric.samples {|sample| yield sample}
      return nil
    end

    forward_missing_to(@metric)
  end
end
