require "./sample"
require "./registry"

module Crometheus
# `Metric` is the base class for individual metrics types.
#
# If you want to create your own custom metric types, you'll need to
# subclass `Metric`.
# `#samples` is the only abstract method you'll need to override; then
# you will also need to implement your custom instrumentation.
# You'll probably also want to define `.type` on your new class; it
# should return a member of enum `Type`.
# The following is a perfectly serviceable, if useless, metric type:
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

    # Initializes `name` and `docstring`, then passes `self` to
    # `register_with.register` if not `nil`.
    # Raises an `ArgumentError` if `name` does not conform to
    # Prometheus' standards.
    def initialize(@name : Symbol,
                   @docstring : String,
                   register_with : Crometheus::Registry? = Crometheus.default_registry)
      unless name.to_s =~ /^[a-zA-Z_:][a-zA-Z0-9_:]*$/
        raise ArgumentError.new("#{name} does not match [a-zA-Z_:][a-zA-Z0-9_:]*")
      end

      register_with.try &.register(self)
    end

    # Yields one `Sample` for each time series this metric represents.
    # Called by `Registry` to collect data for exposition.
    # Users generally do not need to call this.
    abstract def samples(&block : Sample -> Nil) : Nil

    # Returns the type of Prometheus metric this class represents.
    # Should be overridden to return the appropriate member of `Type`.
    # Called by `Registry` to determine metric type to report to
    # Prometheus.
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
    # different labelsets.
    # It takes two type parameters, one for the type of `Metric` to
    # to collect, and one `NamedTuple` mapping label names to `String`
    # values.
    # Since this is cumbersome to type out, you generally won't refer to
    # `LabeledMetric` directly in your code; instead, use `Metric.[]` or
    # `Crometheus.alias` to generate an appropriate `LabeledMetric`
    # type.
    #
    # Storing labelsets as `NamedTuple`s allows the compiler to enforce
    # the constraint that every metric in the collection have the same
    # set of label names.
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
      # Takes one keyword argument for each of this metric's labels.
      def [](**labels : **LabelType)
        @metrics[labels]
      end

      # Returns an array of every labelset currently ascribed to a
      # metric.
      def get_labels : Array(LabelType)
        return @metrics.keys
      end

      # Deletes the metric with the given labelset from the collection.
      # Takes one keyword argument for each of this metric's labels.
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
      # See `Metric#samples`.
      def samples(&block : Sample -> Nil)
        @metrics.each do |labels, metric|
          metric.samples {|ss| ss.labels.merge!(labels.to_h); yield ss}
        end
        return nil
      end
    end

    # Convenience macro for generating a `LabeledMetric` with
    # appropriate type parameters.
    # Takes any number of `Symbol`s as arguments, returning a
    # `LabeledMetric` class object with those arguments as label names.
    # Note that this macro causes type inference to fail when used with
    # class or instance variables; see `Crometheus.alias` for that use
    # case.
    #```
    # require "crometheus/gauge"
    #
    # ages = Crometheus::Gauge[:first_name, last_name].new(:age, "Age of person")
    # ages[first_name: "Jane", last_name: "Doe"].set 32
    # ages[first_name: "Sally", last_name: "Generic"].set 49
    # # ages[first_name: "Jay", middle_initial: "R", last_name: "Hacker"].set 46
    # # => compiler error; label names don't match.
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

  # Convenience macro for aliasing a constant identifier to a
  # `Metric::LabeledMetric` type.
  # Unfortunately, the `Metric.[]` macro breaks type inference when used to
  # initialize a class or instance variable.
  # This can be worked around by using this macro to generate a
  # friendly alias that allows the compiler to do type inference.
  # The syntax is exactly the same as the ordinary `alias` keyword,
  # except that the aliased type must be a `Metric::LabeledMetric` specified
  # with the notation documented in `Metric.[]`.
  # See
  # [Crystal issue #4039](https://github.com/crystal-lang/crystal/issues/4039)
  # for more information.
  #```
  # require "crometheus/counter"
  #
  # class TollBooth
  #   Crometheus.alias CarCounter = Crometheus::Counter[:make, :model]
  #   def initialize
  #     @money = Crometheus::Counter.new(:money, "Fees collected")
  #     # Non-labeled metrics can be instantiated normally
  #     @counts = CarCounter.new(:cars, "Number of cars driven")
  #   end
  #
  #   def count_car(make, model)
  #     @money.inc(5)
  #     @counts[make: make, model: model].inc
  #   end
  # end
  #```
  macro alias(assignment)
    {% unless assignment.is_a?(Assign) &&
              assignment.target.is_a?(Path) &&
              assignment.value.is_a?(Call) &&
              assignment.value.receiver.is_a?(Path) &&
              assignment.value.name.stringify == "[]" %}
      {% raise "Crometheus aliases must take this form:\n`#{@type}.alias MyType = SomeMetricType[:label1, :label2, ... ]`" %}
    {% end %}
    alias {{ assignment.target }} = Crometheus::Metric::LabeledMetric(
      NamedTuple(
        {% for label in assignment.value.args %}
          {{ label.id }}: String,
        {% end %}
      ),
      {{ assignment.value.receiver }}
    )
  end
end
