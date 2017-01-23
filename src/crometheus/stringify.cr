module Crometheus
  # Prometheus represents infinities as "+Inf" or "Inf" or "-Inf"
  # and NaN's as "Nan". I'm not sure if it will accept Crystal's
  # representations, which are different.
  # TODO: check if this is necessary
  # Note that if the value is not +/-INFINITY or NAN, you still need to
  # do the to_s conversion yourself.
  def self.stringify(ff : Float64) : String | Float64
    case ff
    when Float64::INFINITY
      "+Inf"
    when -Float64::INFINITY
      "-Inf"
    when ff
      ff
    else
      "Nan"
    end
  end

  # I believe the following will be more efficient once
  # https://github.com/crystal-lang/crystal/issues/3923 is resolved.
  # private def stringify(ff : Float64) : String | Float64
  #   return @@stringify_dict[ff]
  # rescue KeyError
  #   return ff
  # end
  # @@stringify_dict = {
  #   Float64::INFINITY => "+Inf",
  #   -Float64::INFINITY => "-Inf",
  #   Float64::NAN => "Nan"}
end
