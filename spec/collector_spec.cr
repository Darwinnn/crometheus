require "./spec_helper"
require "../src/crometheus/collector"
require "../src/crometheus/gauge"
require "../src/crometheus/histogram"
require "../src/crometheus/sample"

describe Crometheus::Collector(Crometheus::Gauge) do
  gauge_collector = Crometheus::Collector(Crometheus::Gauge).new(:foo, "bar")

  describe ".new" do
    it "automatically registers with the default registry" do
      Crometheus.default_registry.collectors.first.should eq gauge_collector
    end

    it "registers with a registry passed to the constructor" do
      registry = Crometheus::Registry.new
      gauge_collector2 = Crometheus::Collector(Crometheus::Gauge).new(:baz, "quux", registry)
      registry.collectors.should eq [gauge_collector2]
      Crometheus.default_registry.collectors.should_not contain gauge_collector2
    end

    it "rejects unacceptable names" do
      expect_raises(ArgumentError) do
        Crometheus::Collector(Crometheus::Gauge).new(:"123", "")
      end
    end

    it "passes unknown kwargs to Metric objects" do
      histogram = Crometheus::Collector(Crometheus::Histogram).new(
        :histogram_name, "", nil, buckets: [1.0, 2.0]
      )
      histogram.buckets.keys.should eq([1.0, 2.0, Float64::INFINITY])
      histogram[label: "value"].buckets.keys.should eq([1.0, 2.0, Float64::INFINITY])
    end

    it "creates labeled metrics according to base_labels" do
      # Hash format
      gauge = Crometheus::Collector(Crometheus::Gauge).new(
        :gauge_name, "", nil, [
          {:label => "value1"},
          {:label => "value2"},
          {:label => "value3"}
        ])
      samples = [] of Crometheus::Sample
      gauge.collect {|ss| samples << ss}
      samples.should eq [
        Crometheus::Sample.new(0.0, labels: {:label => "value1"}),
        Crometheus::Sample.new(0.0, labels: {:label => "value2"}),
        Crometheus::Sample.new(0.0, labels: {:label => "value3"})
      ]
      # NamedTuple format
      gauge = Crometheus::Collector(Crometheus::Gauge).new(
        :gauge_name, "", nil, [
          {label: "value4"},
          {label: "value5"}
        ])
      samples = [] of Crometheus::Sample
      gauge.collect {|ss| samples << ss}
      samples.should eq [
        Crometheus::Sample.new(0.0, labels: {:label => "value4"}),
        Crometheus::Sample.new(0.0, labels: {:label => "value5"})
      ]
    end
  end

  describe "#labels" do
    it "creates a new metric for each given label" do
      gauge = Crometheus::Collector(Crometheus::Gauge).new(:gauge_name, "", nil)
      gauge.set 100
      g1 = gauge[foo: "bar"]
      g1.get.should eq 0.0
      g1.inc 20
      gauge[foo: "bar"].get.should eq 20.0
      gauge[foo: "bar"].should eq g1
    end
  end

  describe "#get_labels" do
    it "returns an array of all used labelsets" do
      gauge = Crometheus::Collector(Crometheus::Gauge).new(:gauge_name, "", nil)
      gauge[foo: "bar"].set 1
      gauge[baz: "quux"]
      gauge.get_labels.should eq [{:foo => "bar"}, {:baz => "quux"}]
    end
  end

  describe "#remove" do
    it "should delete the specified metric" do
      gauge = Crometheus::Collector(Crometheus::Gauge).new(:gauge_name, "", nil)
      gauge[foo: "bar"].set 1
      gauge[baz: "quux"]
      gauge.remove(foo: "bar")
      gauge.get_labels.should eq [{:baz => "quux"}]
    end
  end

  describe "#clear" do
    it "should delete all metrics" do
      gauge = Crometheus::Collector(Crometheus::Gauge).new(:gauge_name, "", nil)
      gauge[foo: "bar"].set 1
      gauge[baz: "quux"]
      gauge.clear
      gauge.get_labels.should eq [] of Hash(Symbol, String)
    end
  end

  describe "#collect" do
    it "should yield samples for each labelset" do
      gauge = Crometheus::Collector(Crometheus::Gauge).new(:gauge_name, "", nil)
      gauge.set 100.0
      gauge[foo: "bar"].set 20.0
      samples = [] of Crometheus::Sample
      gauge.collect {|ss| samples << ss}
      samples.should eq [
        Crometheus::Sample.new(value: 100.0),
        Crometheus::Sample.new(value: 20.0, labels: {:foo => "bar"})
      ]
    end
  end
end
