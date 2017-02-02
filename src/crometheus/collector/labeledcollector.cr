require "../collector"

module Crometheus
  class LabeledCollector(LabelType, MetricType) < Collector
    @metrics : Hash(LabelType, MetricType)

    def initialize(name : Symbol,
                   docstring : String,
                   register_with : Crometheus::Registry? = Crometheus.default_registry,
                   **metric_params)
      @metrics = Hash(LabelType, MetricType).new {|hh, kk|
        hh[kk] = MetricType.new(**metric_params)}

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
    def [](**labels : **LabelType)
      @metrics[labels]
    end

    # `labels()` can be used as an alias for `[]`.
    def labels(**labels : **LabelType)
      self[**labels]
    end

    # Returns an array of every labelset currently assigned a value.
    def get_labels : Array(LabelType)
      return @metrics.keys
    end

    # Deletes the metric with the given labelset from the collector.
    def remove(**labels : **LabelType)
      @metrics.delete(labels)
    end

    # Deletes all metrics from the collector.
    def clear
      @metrics.clear
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
      @metrics.each do |labels, metric|
        #~ metric.samples {|ss| ss.labels.merge!(labels.to_h); yield ss}
        metric.samples {|ss|
          yield Sample.new(ss.value, labels: ss.labels.merge(labels.to_h), suffix: ss.suffix)
        }
      end
      return nil
    end

  end
end
