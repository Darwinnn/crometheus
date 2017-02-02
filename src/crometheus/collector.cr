require "./registry"

module Crometheus
  # Non-generic abstract base type, because this works:
  #     [] of CollectorBase
  # But this gives an error:
  #     [] of Collector
  # "can't use Crometheus::Collector(T) as generic type argument yet,
  # use a more specific type".
  abstract class Collector
    property name : Symbol
    property docstring : String

    def initialize(@name : Symbol, @docstring : String, register_with : Crometheus::Registry? = Crometheus.default_registry)
      if register_with
        register_with.register(self)
      end

      unless name.to_s =~ /[a-zA-Z_:][a-zA-Z0-9_:]*/
        raise ArgumentError.new("#{name} does not match [a-zA-Z_:][a-zA-Z0-9_:]*")
      end

      unless [:gauge, :counter, :histogram, :summary, :untyped].includes? type
        raise ArgumentError.new("Metric type must be one of :gauge, "\
          ":counter, :histogram, :summary, :untyped")
      end

    end

    abstract def collect(&block : Sample -> Nil)
    abstract def type : Symbol

    macro [](metricType)
      Crometheus::UnlabeledCollector({{metricType}})
    end

    macro [](metricType, labels)
      Crometheus::LabeledCollector(
        NamedTuple(
          {% for label in labels %}
            {{ label.id }}: String,
          {% end %}
        ),
        {{metricType}}
      )
    end
  end

  #~ # The `Collector` represents what in the Prometheus literature is
  #~ # generally referred to as a "metric"; i.e. all data gathered under
  #~ # a given metric name. In Crometheus, a `Collector` is a grouping of
  #~ # zero or more `Metric` objects, each identified by a particular
  #~ # set of labels.
  #~ #
  #~ # `T` must be a subclass of class `Metric`, or at least behave like
  #~ # one.
  #~ class Collector(T) < CollectorBase
    #~ @metrics = {} of Hash(Symbol, String) => T
    #~ @labels : Array(Symbol)?

    #~ # Creates a new Collector.
    #~ #
    #~ # * `name` - the name of the collector. This will be converted to a
    #~ # `String` and used as the metric name when exporting to Prometheus.
    #~ # * `docstring` - a description of the collector. This will be used
    #~ # on the HELP line when exporting to Prometheus.
    #~ # * `register_with` - an optional `Registry` instance. By default,
    #~ # metrics register with the default `Registry` accessible via
    #~ # `Crometheus.default_registry`. Set this value to a different
    #~ # `Registry` or `nil` to override this behavior.
    #~ # * `base_labels` - an array of labelsets, given as either
    #~ # named tuples, hashes of `Symbol` to `String`, or `nil`, which is
    #~ # equivalent to the empty tuple. For each entry in the array, the
    #~ # constructor will initialize a `Metric` with the given labelset.
    #~ # For example, passing `base_labels: [{foo: "bar"}, {foo: "baz"}]`
    #~ # in the constructor to `coll` is equivalent to calling
    #~ # `coll[foo: "bar"]; coll[foo: "baz"]` immediately after calling
    #~ # `.new`.
    #~ # * `**metric_params` - any additional keyword arguments will be
    #~ # passed to the constructor of any `Metric` objects created by this
    #~ # `Collector`. This is useful for metric types such as `Histogram`,
    #~ # which requires an array of buckets for initialization.
    #~ def initialize(name : Symbol,
                   #~ docstring : String,
                   #~ base_labels : Array(Symbol)? = nil,
                   #~ register_with : Crometheus::Registry? = Crometheus.default_registry,
                   #~ **metric_params)
      #~ @new_metric = Proc(Hash(Symbol, String), T).new do |labelset|
        #~ T.new(labelset, **metric_params)
      #~ end

      #~ if base_labels
        #~ @labels = base_labels.sort
      #~ end

      #~ base_labels.each do |labels|
        #~ label_hash = self.class.labels_to_h(labels)
        #~ @metrics[label_hash] = @new_metric.call(label_hash)
      #~ end
      #~ super(name, docstring, register_with)
    #~ end

    #~ # Fetches a metric (of type `T`) with the given labels, initializing
    #~ # it with default values if necessary.
    #~ # ```
    #~ # require "crometheus/collector"
    #~ # require "crometheus/gauge"
    #~ # include Crometheus
    #~ #
    #~ # animals = Collector(Gauge).new(:animals, "animal counts")
    #~ # animals[animal: "lion"].inc(3)
    #~ # animals[animal: "bear"].inc(2)
    #~ # ```
    #~ # `Collector` automatically forwards
    #~ # unrecognized methods to `self[]`, so this method is not necessary
    #~ # to operate on the metric with the empty labelset.
    #~ # ```
    #~ # animals.set 10
    #~ # animals.get # => 10
    #~ # animals[].get # => 10
    #~ # ```
    #~ def [](**labels)
      #~ label_hash = self.class.labels_to_h(labels)
      #~ return @metrics[label_hash] ||= @new_metric.call(label_hash)
    #~ end

    #~ # `labels()` can be used as an alias for `[]`.
    #~ def labels(**labels)
      #~ self[**labels]
    #~ end

    #~ # Returns an array of every labelset currently assigned a value.
    #~ def get_labels : Array(Hash(Symbol, String))
      #~ return @metrics.keys
    #~ end

    #~ # Deletes the metric with the given labelset from the collector.
    #~ def remove(**labels)
      #~ label_hash = self.class.labels_to_h(labels)
      #~ @metrics.delete(label_hash)
    #~ end

    #~ # Deletes all metrics from the collector.
    #~ def clear
      #~ @metrics.clear
    #~ end

    #~ # Returns the type of metric being collected. Will return one of
    #~ # `:gauge`, `:counter`, `:histogram`, `:summary`, or `:untyped`.
    #~ def type
      #~ T.type
    #~ end

    #~ # Iteratively calls `samples` on each metric in the collector,
    #~ # yielding each received `Sample`. `Registry` uses this to iterate
    #~ # over every sample in the collection. Users generally need not call
    #~ # it.
    #~ def collect(&block : Sample -> Nil)
      #~ @metrics.each_value do |metric|
        #~ metric.samples {|ss| yield ss}
      #~ end
      #~ return nil
    #~ end

    #~ forward_missing_to(self[])

    #~ protected def self.labels_to_h(labels : Hash(Symbol, String) | NamedTuple | Nil) : Hash(Symbol, String)
      #~ if labels.is_a? NamedTuple
        #~ labelset = {} of Symbol => String
        #~ labels.each do |k,v|
          #~ labelset[k] = v.to_s
        #~ end
        #~ return labelset
      #~ elsif labels.nil?
        #~ return {} of Symbol => String
      #~ end
      #~ return labels
    #~ end
  #~ end


end

require "./collector/unlabeledcollector"
require "./collector/labeledcollector"
