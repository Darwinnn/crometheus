require "./sample"
require "./registry"

module Crometheus
# `Metric` is the base class for individual metrics types.
#
# If you want to create your own custom metric types, you'll need to
# subclass `Metric`. `#samples(&block : Sample -> Nil)` is
# the only abstract methods you'll need to override; then you will also
# need to implement your custom instrumentation. You'll probably also
# want to define `.type` on your new class; it should return a member of
# enum `Type`. The following is a perfectly serviceable, if useless,
# metric type:
#```
# require "crometheus/metric"
#
# class Randometric < Crometheus::Metric
#   def self.type
#     Type::Gauge
#   end
#
#   def samples(&block : Crometheus::Sample -> Nil)
#     yield Crometheus::Sample.new my_value_method
#   end
#
#   def my_value_method
#     rand(10).to_f64
#   end
# end
#```
# See the source to the `Counter`, `Gauge`, `Histogram`, and `Summary`
# classes for more detailed examples of how to subclass `Metric`.
  abstract class Metric
    # The name of the metric. This will be converted to a `String` and
    # exported to Prometheus.
    getter name : Symbol
    # The docstring that appears in the `HELP` line of the exported
    # metric.
    getter docstring : String

    # Initializes `name` and `docstring`, then passes self to
    # `#register` on the `default_registry`, or on the passed
    # `Registry`, if not `nil`. Raises an `ArgumentError` if `name`
    # does not conform to Prometheus' standards.
    def initialize(@name : Symbol,
                   @docstring : String,
                   register_with : Crometheus::Registry? = Crometheus.default_registry)
      unless name.to_s =~ /^[a-zA-Z_:][a-zA-Z0-9_:]*$/
        raise ArgumentError.new("#{name} does not match [a-zA-Z_:][a-zA-Z0-9_:]*")
      end

      if register_with
        register_with.register(self)
      end
    end

    # Yields one `Sample` for each time series this metric represents.
    # Called by `Registry` to collect data for exposition.
    # Users generally do not need to call this.
    abstract def samples(&block : Sample -> Nil) : Nil

    # Returns the type of Prometheus metric this class represents.
    # Should be overridden to return the appropriate member of `Type`.
    # Called by `Registry` to determine metric type.
    # Users generally do not need to call this.
    def self.type
      Type::Untyped
    end

    # Called by `#initialize` to validate that this `Metric`'s labels
    # do not violate any of Prometheus' naming rules. Returns `false`
    # under any of these conditions:
    # * the label is `:job` or `:instance`
    # * the label starts with `__`
    # * the label is not alphanumeric with underscores
    #
    # This generally does not need to be called manually.
    def self.valid_label?(label : Symbol) : Bool
      return false if [:job, :instance].includes?(label)
      ss = label.to_s
      return false if ss !~ /^[a-zA-Z_][a-zA-Z0-9_]*$/
      return false if ss.starts_with?("__")
      return true
    end

    enum Type
      Gauge
      Counter
      Histogram
      Summary
      Untyped

      def to_s(io : IO)
        io << case self
        when .gauge?; "gauge"
        when .counter?; "counter"
        when .histogram?; "histogram"
        when .summary?; "summary"
        else; "untyped"
        end
      end
    end

    # `LabeledMetric` is a generic type that acts as a collection of
    # `Metric` objects exported under the same metric name, but with
    # different labelsets. You generally won't refer to `LabeledMetric`
    # directly in your code; instead, use `Metric.[]` to generate an
    # appropriate `LabeledMetric` type.
    #
    # Label names are stored as a `NamedTuple` that maps `Symbol`s to
    # `String`s. This allows the compiler to enforce the constraint that
    # every metric in the collection have the same set of label names.
    class LabeledMetric(LabelType, MetricType) < Metric
      @metrics : Hash(LabelType, MetricType)

      # Creates a `LabeledMetric`, saving `**metric_params` for passage
      # to the constructors of each metric in the collection.
      def initialize(name : Symbol,
                     docstring : String,
                     register_with : Crometheus::Registry? = Crometheus.default_registry,
                     **metric_params)
        super(name, docstring, register_with)

        @metrics = Hash(LabelType, MetricType).new do |hh,kk|
          hh[kk] = MetricType.new(**metric_params,
                                  name: name,
                                  docstring: docstring,
                                  register_with: nil)
        end
      end

      # Fetches the metric with the given labelset.
      def [](**labels : **LabelType)
        @metrics[labels]
      end

      # Returns an array of every labelset currently ascribed to a
      # metric.
      def get_labels : Array(LabelType)
        return @metrics.keys
      end

      # Deletes the metric with the given labelset from the collection.
      def remove(**labels : **LabelType)
        @metrics.delete(labels)
      end

      # Deletes all metrics from the collection.
      def clear
        @metrics.clear
      end

      # Returns `MetricType.type`. See `Metric::Type`.
      def self.type
        MetricType.type
      end

      # Iteratively calls `samples` on each metric in the collection,
      # yielding each received `Sample`.
      def samples(&block : Sample -> Nil)
        @metrics.each do |labels, metric|
          metric.samples {|ss| ss.labels.merge!(labels.to_h); yield ss}
        end
        return nil
      end

    end

    # With a series of `Symbol`s passed as arguments, returns a
    # `LabeledMetric` class object with the appropriate type parameters.
    #```
    # require "crometheus/gauge"
    #
    # ages = Crometheus::Gauge[:first_name, last_name].new(:age, "Age of person")
    # ages[first_name: "Jane", last_name: "Doe"].set 32
    # ages[first_name: "Sally", last_name: "Generic"].set 49
    # # ages[first_name: "Jay", middle_initial: "R", last_name: "Hacker"].set 46
    # # => compiler error: "no overload matches..."
    #```
    macro [](*labels)
      Crometheus::Metric::LabeledMetric(
        NamedTuple(
          {% for label in labels %}
            {{ label.id }}: String,
          {% end %}
        ),
        {{@type}}
      )
    end
  end
end
