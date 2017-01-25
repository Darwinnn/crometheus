require "./registry"

module Crometheus
  # Non-generic abstract base type, because this works:
  #     [] of CollectorBase
  # But this gives an error:
  #     [] of Collector
  # "can't use Crometheus::Collector(T) as generic type argument yet,
  # use a more specific type".
  private abstract class CollectorBase
    property name : Symbol
    property docstring : String

    def initialize(@name : Symbol, @docstring : String, register_with : Crometheus::Registry? = Crometheus.registry)
      if register_with
        register_with.register(self)
      end
    end

    abstract def collect(&block : Sample -> Nil)
  end

  # A Collector is a grouping of one or more related metrics. These
  # metrics all have the same name, but may have different sets of
  # labels. Each particular data point is defined by a unique labelset.
  # T must be a subclass of class `Metric`.
  class Collector(T) < CollectorBase
    # When Collector is initialized, a metric of type T is automatically
    # instantiated. This is the default, unlabelled data series for this
    # collector. Methods not defined on Collector will be forwarded to
    # this metric automatically, so you don't generally need to
    # call #metric - if c is a collector, c.get is equivalent to
    # c.metric.get.
    property metric : T
    @children = {} of Hash(Symbol, String) => T

    # Creates a new Collector.
    #
    # name : The name of the collector. This will be converted to a
    # String and used as the metric name when exporting to Prometheus.
    # register_with : an optional Registry instance. By default, metrics
    # register with the default Registry accessible with
    # Crometheus.registry. Set this value to a different Registry or nil
    # to override this behavior.
    def initialize(name : Symbol, docstring : String, register_with : Crometheus::Registry? = Crometheus.registry, **metric_params)
      super(name, docstring, register_with)
      # Capture the code for generating a new Metric as a Proc, since
      # keeping metric_params around is hard without knowing its type.
      @new_metric = Proc(Hash(Symbol, String), T).new do |labelset|
        T.new(labelset, **metric_params)
      end
      @metric = @new_metric.call({} of Symbol => String)
    end

    # Fetches a child metric with the given labelset, creating it with
    # default values if necessary.
    def labels(**tuple)
      labelset = tuple.to_h
      return @children[labelset] ||= @new_metric.call(labelset)
    end

    # [] can be used as an alias for labels().
    def [](**tuple)
      labels(**tuple)
    end

    # collect() is called by `Registry` to iterate over every sample in the
    # collection. Users generally need not call it.
    def collect(&block : Sample -> Nil)
      @metric.samples {|ss| yield ss}
      @children.each_value do |metric|
        metric.samples {|ss| yield ss}
      end
      return nil
    end

    forward_missing_to(metric)
  end


end
