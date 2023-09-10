module Crometheus
  # Represents NaN's and infinities in the same format as Prometheus.
  # Prometheus represents infinities as "+Inf" or "-Inf"
  # and NaN's as "NaN". We want to use those representations instead of
  # the ones Crystal uses, to ensure compatability and minimize surprise
  # in histogram labels.
  # Note that this only performs a conversion to String if the Float64
  # has one of the mentioned values; this is to avoid extra String
  # allocations in use cases like `io << stringify(my_float)`.
  # If you want a guaranteed String returned you'll still need to use
  # `to_s` on the result.
  def self.stringify(ff : Float64 | Int64 | Int32) : String | Float64 | Int64
    case ff
    when Float64::INFINITY || Int64::MAX || Int32::MAX
      "+Inf"
    when -Float64::INFINITY || -Int64::MAX || -Int32::MAX
      "-Inf"
    when ff
      ff
    else
      "NaN"
    end
  end
end
