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
      unless self.class.valid_labels?(@labels)
        raise ArgumentError.new("Invalid labels")
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
    def self.valid_labels?(labelset : Hash(Symbol, String))
      labelset.each_key do |key|
        return false if [:job, :instance].includes?(key)
        ss = key.to_s
        return false if ss !~ /^[a-zA-Z_][a-zA-Z0-9_]*$/
        return false if ss.starts_with?("__")
      end
      return true
    end
  end
end
