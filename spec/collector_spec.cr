require "./spec_helper"
require "../src/crometheus/collector"
require "../src/crometheus/gauge"
require "../src/crometheus/histogram"
require "../src/crometheus/sample"

describe Crometheus::Collector(Crometheus::Gauge) do
  gauge_collector = Crometheus::Collector(Crometheus::Gauge).new(:foo, "bar")

  describe ".new" do
    it "automatically registers with the default registry" do
      Crometheus.registry.collectors.first.should eq gauge_collector
    end

    it "registers with a registry passed to the constructor" do
      registry = Crometheus::Registry.new
      gauge_collector2 = Crometheus::Collector(Crometheus::Gauge).new(:baz, "quux", registry)
      registry.collectors.should eq [gauge_collector2]
      Crometheus.registry.collectors.should_not contain gauge_collector2
    end

    it "passes unknown kwargs to Metric objects" do
      histogram = Crometheus::Collector(Crometheus::Histogram).new(
        :histogram_name, "", nil, buckets: [1.0, 2.0]
      )
      histogram.buckets.keys.should eq([1.0, 2.0, Float64::INFINITY])
      histogram[label: "value"].buckets.keys.should eq([1.0, 2.0, Float64::INFINITY])
    end
  end

  describe "#labels" do
    it "creates a new metric for each given label" do
      gauge_collector.set 100
      g1 = gauge_collector.labels(foo: "bar")
      g1.get.should eq 0.0
      g1.inc 20
      gauge_collector.labels(foo: "bar").get.should eq 20.0
      gauge_collector[foo: "bar"].should eq g1
    end
  end

  describe "#collect" do
    it "should yield samples for each labelset" do
      samples = [] of Crometheus::Sample
      gauge_collector.collect {|ss| samples << ss}
      samples.should eq [
        Crometheus::Sample.new(value: 100.0),
        Crometheus::Sample.new(value: 20.0, labels: {:foo => "bar"})
      ]
    end
  end
end
