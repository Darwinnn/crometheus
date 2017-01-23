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
    property metric
    @children = {} of Hash(Symbol, String) => T

    # Creates a new Collector.
    def initialize(name : Symbol, docstring : String, register_with : Crometheus::Registry? = Crometheus.registry)
      super(name, docstring, register_with)
      @metric = T.new(@name, {} of Symbol => String)
    end

    # Fetch or create a child metric with the given labelset
    def labels(**tuple)
      labelset = tuple.to_h
      return @children[labelset] ||= T.new(@name, labelset)
    end
    def [](**tuple)
      labels(**tuple)
    end

    # This is called by `Registry` to iterate over every sample in the
    # collection.
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
