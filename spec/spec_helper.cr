require "spec"

class CrometheusTestException < Exception
end

def get_samples(metric : Crometheus::Metric)
  samples = Array(Crometheus::Sample).new
  metric.samples { |ss| samples << ss }
  return samples
end
