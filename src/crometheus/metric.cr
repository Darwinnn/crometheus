require "./sample"

module Crometheus
# Base class for individual metrics.
# You want to instantiate `Collector`(T), not this.
# See the `Gauge`, `Histogram`, and `Summary` classes for examples of
# how to subclass a Metric.
# But the short version is: override get() to either return an instance
# variable or calculate some value dynamically.
  abstract class Metric
    @name : Symbol
    @labels : Hash(Symbol, String)

    def initialize(@name, @labels = {} of Symbol => String)
      @labels.each_key do |label|
        unless self.class.valid_label?(label)
          raise ArgumentError.new("Invalid label: #{label}")
        end
      end
    end

    # Specifies this metric as "gauge", "counter", "summary",
    # "histogram", or "untyped".
    abstract def type : String

    # Yields a `Sample` object for each data point this metric returns.
    abstract def samples(&block : Sample -> Nil) : Nil

    # As samples(&block : Sample -> Nil), but appends `Sample`s to the
    # given Array rather than yielding them. Don't override this
    # samples(); it comes for free with the other one.
    def samples(ary : Array(Sample) = Array(Sample).new) : Array(Sample)
      samples {|ss| ary << ss}
      return ary
    end

    # Validates a label set for this metric type
    def self.valid_label?(label : Symbol)
      return false if [:job, :instance].includes?(label)
      ss = label.to_s
      return false if ss !~ /^[a-zA-Z_][a-zA-Z0-9_]*$/
      return false if ss.starts_with?("__")
      return true
    end

    private def make_sample(value : Float64, labels = {} of Symbol => String, suffix = "")
      Crometheus::Sample.new(value: value,
                             labels: @labels.merge(labels),
                             suffix: suffix)
    end
  end
end
