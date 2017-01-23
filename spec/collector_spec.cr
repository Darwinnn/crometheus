require "./spec_helper"
require "../src/crometheus/collector"
require "../src/crometheus/gauge"
require "../src/crometheus/sample"

describe Crometheus::Collector(Crometheus::Gauge) do
  gauge = Crometheus::Collector(Crometheus::Gauge).new(:foo, "bar")
  it "automatically registers with the default registry" do
    Crometheus.registry.collectors.first.should eq gauge
  end

  it "registers with a registry passed to the constructor" do
    registry = Crometheus::Registry.new
    gauge2 = Crometheus::Collector(Crometheus::Gauge).new(:baz, "quux", registry)
    registry.collectors.should eq [gauge2]
    Crometheus.registry.collectors.should_not contain gauge2
  end

  #~ describe "#collect" do
    #~ it "collects samples from all metrics" do
      #~ gauge.set(1.28e34)
      #~ gauge.labels(foo: "bar", baz: "quux").set(-13)
      #~ gauge.labels(one: "two", three: "four").set(Float64::INFINITY)

      #~ gauge.collect.should eq([
        #~ Crometheus::Sample.new(value: 1.28e34),
        #~ Crometheus::Sample.new(value: -13.0, labels: {:foo => "bar", :baz => "quux"}),
        #~ Crometheus::Sample.new(value: Float64::INFINITY, labels: {:one => "two", :three => "four"})])
    #~ end
  #~ end
end
