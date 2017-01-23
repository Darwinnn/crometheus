require "./metric"

module Crometheus
  class Summary < Metric
    @count = 0.0
    @sum = 0.0

    def observe(value : Int | Float)
      @count += 1.0
      @sum += value.to_f64
    end

    def count
      @count
    end

    def sum
      @sum
    end

    def reset
      @count = 0.0
      @sum = 0.0
    end

    def measure_runtime(&block)
      t0 = Time.now
      begin
        yield
      ensure
        t1 = Time.now
        observe((t1 - t0).to_f)
      end
    end

    def samples(&block : Sample -> Nil) : Nil
      yield Crometheus::Sample.new(suffix: "_count", value: @count, labels: @labels)
      yield Crometheus::Sample.new(suffix: "_sum", value: @sum, labels: @labels)
    end

    def type
      "summary"
    end

    def self.valid_label?(label : Symbol)
      return false if :quantile == label
      return super
    end
  end
end
