# Base class for individual metrics.
# You want to instantiate Collection(T), not this.
# See the Gauge, Histrogram, and Summary classes for examples of how to
# subclass a Metric.
# But the short version is: override get() to either return an instance
# variable or calculate some value dynamically.
module Crometheus
  class Metric
    @name : Symbol
    @labels : Hash(Symbol, String)

    def initialize(@name, @labels)
      unless self.class.valid_labels?(@labels)
        raise ArgumentError.new("Invalid labels")
      end
    end

    def get : Float64
      0.0
    end

    def type
      "untyped"
    end

    def to_s(io)
      io << @name
      unless @labels.empty?
        io << '{' << @labels.map{|k,v| "#{k}=\"#{v}\""}.join(", ") << '}'
      end
      io << ' ' << get << '\n'
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
