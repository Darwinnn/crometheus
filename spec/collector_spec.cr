require "./spec_helper"
require "../src/crometheus/collector"
require "../src/crometheus/gauge"
require "../src/crometheus/histogram"
require "../src/crometheus/sample"

describe Crometheus::Collector[Crometheus::Gauge] do
  gauge_collector = Crometheus::Collector[Crometheus::Gauge].new(:foo, "bar")

  describe ".new" do
    it "automatically registers with the default registry" do
      Crometheus.default_registry.collectors.first.should eq gauge_collector
    end

    it "registers with a registry passed to the constructor" do
      registry = Crometheus::Registry.new
      gauge_collector2 = Crometheus::Collector[Crometheus::Gauge].new(:baz, "quux", registry)
      registry.collectors.should eq [gauge_collector2]
      Crometheus.default_registry.collectors.should_not contain gauge_collector2
    end

    it "rejects unacceptable names" do
      expect_raises(ArgumentError) do
        Crometheus::Collector[Crometheus::Gauge].new(:"123", "")
      end
    end

    it "passes unknown kwargs to Metric objects" do
      histogram = Crometheus::Collector[Crometheus::Histogram].new(
        :histogram_name, "", nil, buckets: [1.0, 2.0]
      )
      histogram.buckets.keys.should eq([1.0, 2.0, Float64::INFINITY])
    end

    pending "fails on invalid labels" do
    end
  end

  describe "#labels" do
    it "creates a new metric for each given label" do
      gauge = Crometheus::Collector[Crometheus::Gauge, {:foo}].new(:gauge_name, "", nil)
      g1 = gauge[foo: "bar"]
      g2 = gauge[foo: "baz"]
      g1.get.should eq 0.0
      g1.inc 20
      gauge[foo: "bar"].get.should eq 20.0
      gauge[foo: "bar"].should eq g1
      gauge[foo: "baz"].get.should eq 0.0
    end
  end

  describe "#get_labels" do
    it "returns an array of all used labelsets" do
      gauge = Crometheus::Collector[Crometheus::Gauge, {:one, :two}].new(:gauge_name, "", nil)
      gauge[one: "hello", two: "goodbye"].set 1
      gauge[one: "apple", two: "pear"]
      gauge.get_labels.should eq [{one: "hello", two: "goodbye"}, {one: "apple", two: "pear"}]
    end
  end

  describe "#remove" do
    it "should delete the specified metric" do
      gauge = Crometheus::Collector[Crometheus::Gauge, {:foo}].new(:gauge_name, "", nil)
      gauge[foo: "bar"].set 1
      gauge[foo: "baz"]
      gauge.remove(foo: "bar")
      gauge.get_labels.should eq [{foo: "baz"}]
    end
  end

  describe "#clear" do
    it "should delete all metrics" do
      gauge = Crometheus::Collector[Crometheus::Gauge, {:foo}].new(:gauge_name, "", nil)
      gauge[foo: "bar"].set 1
      gauge[foo: "baz"]
      gauge.clear
      gauge.get_labels.should eq [] of NamedTuple(foo: String)
    end
  end

  describe "#collect" do
    it "should yield samples for each labelset" do
      gauge = Crometheus::Collector[Crometheus::Gauge].new(:gauge_name, "", nil)
      gauge.set 100.0
      samples = [] of Crometheus::Sample
      gauge.collect {|ss| samples << ss}
      samples.should eq [
        Crometheus::Sample.new(100.0),
      ]

      gauge = Crometheus::Collector[Crometheus::Gauge, {:foo}].new(:gauge_name, "", nil)
      gauge[foo: "bar"].set 100.0
      gauge[foo: "baz"].set 200.0
      samples = [] of Crometheus::Sample
      gauge.collect {|ss| samples << ss}
      samples.should eq [
        Crometheus::Sample.new(100.0, labels: {:foo => "bar"}),
        Crometheus::Sample.new(200.0, labels: {:foo => "baz"})
      ]
    end
  end
end
