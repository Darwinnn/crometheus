require "./spec_helper"
require "../src/crometheus/collector"

# Most of Collector's functionality only makes sense when used with a
# less abstract metric type than Metric (which is always 0.0). See
# gauge_spec.cr for a more thorough test suite.
describe Crometheus::Collector(Crometheus::Metric) do
  it "automatically registers with the default registry" do
    collector = Crometheus::Collector(Crometheus::Metric).new(:foo, "bar")
    Crometheus.registry.collectors.first.should eq collector
  end

  it "registers with a registry passed to the constructor" do
    registry = Crometheus::Registry.new
    collector = Crometheus::Collector(Crometheus::Metric).new(:baz, "quux", registry)
    registry.collectors.first.should eq collector
    Crometheus.registry.collectors.should_not contain collector
  end
end
