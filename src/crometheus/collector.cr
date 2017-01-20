require "./registry"

module Crometheus

  # Non-generic abstract base type, because this works:
  #     [] of CollectorBase
  # But this gives an error:
  #     [] of Collector
  # "can't use Crometheus::Collector(T) as generic type argument yet,
  # use a more specific type".
  private abstract class CollectorBase
    abstract def to_s(io)
  end

  # A Collector is a grouping of one or more related metrics. These
  # metrics all have the same name, but may have different sets of
  # labels. Each particular data point is defined by a unique labelset.
  # T must be a subclass of class `Metric`.
  class Collector(T) < CollectorBase
    property metric
    property name, docstring

    # Creates a new Collector.
    #
    def initialize(@name : Symbol, @docstring : String, registry : Crometheus::Registry? = Crometheus.registry)
      @metric = T.new(@name, {} of Symbol => String)
      @children = {} of Hash(Symbol, String) => T

      if registry
        registry.register(self)
      end
    end

    # Fetch or create a child metric with the given labelset
    def labels(**tuple)
      labelset = tuple.to_h
      return @children[labelset] ||= T.new(@name, labelset)
    end

    # pending https://github.com/crystal-lang/crystal/issues/3918
    #~ def [](**tuple)
      #~ labels(**tuple)
    #~ end

    def to_s(io)
      io << "# HELP " << @name << ' ' << @docstring << '\n'
      io << "# TYPE " << @name << ' ' << @metric.type << '\n'
      io << @metric
      @children.values.each {|child| io << child}
      return io
    end

    forward_missing_to(metric)
  end


end
